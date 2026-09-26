package Plugins::Deezer::SearchPrototype;

# PROTOTYPE - throwaway code on branch prototype/search-menu, never merge.
#
# Answers two questions from the menu redesign:
#   1. Can the LMS-Suche provider hand back a lazy link node that loads the
#      Deezer matches only when tapped?
#   2. How do Kategorien with counts look in Material and on the Squeezebox
#      Radio, compared to grouped previews and a Spotty-like flat list?
#
# Three variants of the Suche result page, switched via the first entry of
# the Suche menu. State (variant, Zuletzt gesucht) lives in memory only.

use strict;
use utf8;

use Time::HiRes;

use Slim::Utils::Log;
use Slim::Utils::Strings qw(cstring);

my $log = logger('plugin.deezer');

my @VARIANTS = (
	[ 'A', 'Kategorien mit Anzahl' ],
	[ 'B', 'Gruppen mit Vorschau' ],
	[ 'C', 'Flach wie Spotty' ],
	[ 'D', 'Wie B, Überschriften mit Symbol' ],
);
my $variant = 0;
my %recent;

# display order, LMS tokens for generic types, Deezer wording otherwise
my @CATEGORIES = (
	[ ARTIST     => sub { cstring($_[0], 'ARTISTS') } ],
	[ ALBUM      => sub { cstring($_[0], 'ALBUMS') } ],
	[ TRACK      => sub { cstring($_[0], 'SONGS') } ],
	[ PLAYLIST   => sub { cstring($_[0], 'PLAYLISTS') } ],
	[ LIVESTREAM => sub { 'Radiosender' } ],
	[ SHOW       => sub { 'Podcasts' } ],
	[ EPISODE    => sub { 'Folgen' } ],
);

my %ICONS = (
	ARTIST => 'html/images/artists.png', ALBUM => 'html/images/albums.png',
	TRACK => 'html/images/playall.png', PLAYLIST => 'html/images/playlists.png',
	LIVESTREAM => 'html/images/radio.png', SHOW => 'plugins/Deezer/html/podcast.png',
	EPISODE => 'plugins/Deezer/html/rss.png',
);

my %TOP_TYPE = (
	artist => 'ARTIST', album => 'ALBUM', song => 'TRACK', playlist => 'PLAYLIST',
	livestream => 'LIVESTREAM', show => 'SHOW', episode => 'EPISODE',
);

sub init {
	Slim::Menu::GlobalSearch->registerInfoProvider( deezer => (
		func => sub {
			my ( $client, $tags ) = @_;
			$log->error("PROTOTYPE LMS-Suche provider called for '$tags->{search}'");

			# name must be exactly "Deezer" for Material's whitelist. A coderef url on
			# this top-level node makes XMLBrowser skip its session id and mis-resolve
			# item_id "_<search>.N", so only the children may be lazy.
			return {
				name  => 'Deezer',
				items => [ {
					name => 'Alle Treffer',
					type => 'link',
					url  => \&results,
					passthrough => [ { query => $tags->{search}, fromLms => 1 } ],
				}, map { {
					name => $_->[1]->($client),
					type => 'link',
					url  => \&_category,
					passthrough => [ { query => $tags->{search}, cat => $_->[0], fromLms => 1 } ],
				} } @CATEGORIES ],
			};
		},
	) );
}

sub menu {
	my ( $client, $cb, $args ) = @_;

	my $userId = Plugins::Deezer::Plugin::getAPIHandler($client)->userId;
	my ($key, $label) = @{$VARIANTS[$variant]};

	my $items = [ {
		name => "PROTOTYP: Variante $key ($label) - antippen zum Wechseln",
		type => 'link',
		url  => sub {
			my ( $client, $cb ) = @_;
			$variant = ($variant + 1) % @VARIANTS;
			$cb->({ items => [ { type => 'text', name => "Jetzt: Variante $VARIANTS[$variant]->[0] ($VARIANTS[$variant]->[1])" } ] });
		},
	}, {
		name => cstring($client, 'SEARCH'),
		type => 'search',
		url  => \&results,
		# Q22: keep Deezer searches out of Jive's own recent search list
		cachesearch => 0,
	} ];

	foreach my $term ( @{$recent{$userId} || []} ) {
		push @$items, {
			name => $term,
			type => 'link',
			image => 'html/images/search.png',
			url  => \&results,
			passthrough => [ { query => $term } ],
		};
	}

	push @$items, {
		name => 'Zuletzt gesucht: Löschen',
		type => 'link',
		url  => sub {
			$recent{$userId} = [];
			$_[1]->({ items => [ { type => 'text', name => 'Gelöscht' } ] });
		},
	} if @{$recent{$userId} || []};

	$cb->({ items => $items });
}

sub results {
	my ( $client, $cb, $args, $params ) = @_;

	my $term = $args->{search} || $params->{query};
	my $api = Plugins::Deezer::Plugin::getAPIHandler($client);

	_remember($api->userId, $term);
	$log->error("PROTOTYPE search '$term', variant $VARIANTS[$variant]->[0], from " . ($params->{fromLms} ? 'LMS-Suche' : 'Suche'));

	my $started = Time::HiRes::time();

	$api->gwCall( sub {
		my $results = $_[0]->{results} || {};
		my $render = ( \&_variantA, \&_variantB, \&_variantC, \&_variantD )[$variant];

		# Q45 b: pageSearch totals are capped, fetch the real ones (one search.music call per Kategorie, in parallel)
		my @cats = grep { $results->{$_} && $results->{$_}->{count} } map { $_->[0] } @CATEGORIES;
		my $pending = scalar @cats;
		my $done = sub {
			$log->error(sprintf("PROTOTYPE search '%s' rendered after %.2fs", $term, Time::HiRes::time() - $started));
			$cb->({ items => $render->($client, $results) });
		};
		return $done->() unless $pending;

		foreach my $cat (@cats) {
			$api->gwCall( sub {
				my $total = ($_[0]->{results} || {})->{total};
				$results->{$cat}->{total} = $total if defined $total;
				$done->() unless --$pending;
			}, {
				method => 'search.music',
				_cacheKey => "proto_searchTotal:$cat:$term",
			}, {
				query => $term, filter => 'ALL', output => $cat, start => 0, nb => 1,
			} );
		}
	}, {
		method => 'deezer.pageSearch',
		_cacheKey => 'proto_pageSearch:' . $term,
	}, {
		query => $term,
		start => 0,
		nb => 40,
		suggest => 'true',
		artist_suggest => 'true',
		top_tracks => 'true',
	} );
}

sub _remember {
	my ( $userId, $term ) = @_;
	my @terms = grep { lc($_) ne lc($term) } @{$recent{$userId} || []};
	unshift @terms, $term;
	$recent{$userId} = [ splice(@terms, 0, 10) ];
}

# A: Top-Ergebnis, then one link per Kategorie with its count
sub _variantA {
	my ( $client, $results ) = @_;

	my $items = _top($client, $results);

	foreach my $category ( _categories($client, $results) ) {
		my ($label, $section, $cat) = @$category;
		push @$items, {
			name  => "$label ($section->{total})",
			type  => 'link',
			url   => \&_category,
			passthrough => [ { query => $results->{QUERY}, cat => $cat } ],
		};
	}

	return $items;
}

# all matches of one Kategorie, paged through search.music (pageSearch caps each section at ~20)
sub _category {
	my ( $client, $cb, $args, $params ) = @_;

	my $index = $args->{index} || 0;
	my $quantity = $args->{quantity} || 50;
	_remember(Plugins::Deezer::Plugin::getAPIHandler($client)->userId, $params->{query}) if $params->{fromLms} && !$index;
	$quantity = 100 if $quantity > 100;
	$log->error("PROTOTYPE category $params->{cat} '$params->{query}' index $index quantity $quantity");

	Plugins::Deezer::Plugin::getAPIHandler($client)->gwCall( sub {
		my $results = $_[0]->{results} || {};
		$log->error("PROTOTYPE category $params->{cat}: total $results->{total}, got " . scalar @{$results->{data} || []});
		$cb->({
			items  => [ map { _renderEntry($client, $params->{cat}, $_) } @{$results->{data} || []} ],
			offset => $index,
			total  => $results->{total},
		});
	}, {
		method => 'search.music',
		_cacheKey => "proto_searchMusic:$params->{cat}:$index:$quantity:$params->{query}",
	}, {
		query => $params->{query},
		filter => 'ALL',
		output => $params->{cat},
		start => $index,
		nb => $quantity,
	} );
}

# B: Top-Ergebnis, then per Kategorie a header, the first 3 matches inline and "alle anzeigen"
sub _variantB {
	my ( $client, $results ) = @_;

	my $items = _top($client, $results);

	foreach my $category ( _categories($client, $results) ) {
		my ($label, $section, $cat) = @$category;
		my @rendered = map { _renderEntry($client, $cat, $_) } @{$section->{data}};

		push @$items, { name => "--- $label ---", type => 'text' };
		push @$items, @rendered[0 .. ($#rendered < 2 ? $#rendered : 2)];
		push @$items, {
			name  => "Alle $section->{total} $label anzeigen",
			type  => 'outline',
			items => \@rendered,
		} if @rendered > 3;
	}

	return $items;
}

# D: like B, but Material-style headers with icon; tapping the header opens all matches
sub _variantD {
	my ( $client, $results ) = @_;

	my $items = [];

	# Top-Ergebnis gets its own header like the Kategorien, but nothing more to open
	my @top = @{_top($client, $results)};
	if (@top) {
		push @$items, { name => 'Top-Ergebnis', type => 'header-basic', image => 'html/images/favorites.png' };
		push @$items, map { $_->{name} =~ s/^Top-Ergebnis: //; $_ } @top;
	}

	foreach my $category ( _categories($client, $results) ) {
		my ($label, $section, $cat) = @$category;
		my @rendered = map { _renderEntry($client, $cat, $_) } @{$section->{data}};

		push @$items, {
			name  => "$label ($section->{total})",
			type  => 'header',
			image => $ICONS{$cat},
			url   => \&_category,
			passthrough => [ { query => $results->{QUERY}, cat => $cat } ],
		};
		push @$items, @rendered[0 .. ($#rendered < 2 ? $#rendered : 2)];
	}

	return $items;
}

# C: Spotty-like, Kategorie links without counts first, then the Titel inline
sub _variantC {
	my ( $client, $results ) = @_;

	my $items = [];

	foreach my $category ( _categories($client, $results) ) {
		my ($label, $section, $cat) = @$category;
		next if $cat eq 'TRACK';
		push @$items, {
			name  => $label,
			type  => 'outline',
			items => [ map { _renderEntry($client, $cat, $_) } @{$section->{data}} ],
		};
	}

	push @$items, map { _renderEntry($client, 'TRACK', $_) } @{$results->{TRACK}->{data} || []};

	return $items;
}

sub _top {
	my ( $client, $results ) = @_;

	return [ map {
		my $cat = $TOP_TYPE{$_->{__TYPE__}};
		my $item = $cat ? _renderEntry($client, $cat, $_) : undef;
		$item->{name} = 'Top-Ergebnis: ' . ($item->{name} || $item->{title}) if $item;
		$item ? $item : ();
	} @{$results->{TOP_RESULT} || []} ];
}

sub _categories {
	my ( $client, $results ) = @_;

	return map {
		my ($cat, $label) = @$_;
		my $section = $results->{$cat};
		$section && $section->{count} ? [ $label->($client), $section, $cat ] : ();
	} @CATEGORIES;
}

# map gw-light entries onto the public API shape the existing renderers expect
sub _renderEntry {
	my ( $client, $cat, $e ) = @_;

	if ( $cat eq 'ARTIST' ) {
		return Plugins::Deezer::Plugin::renderItem($client, {
			type => 'artist', id => $e->{ART_ID}, name => $e->{ART_NAME},
			md5_image => $e->{ART_PICTURE}, picture_type => 'artist',
		});
	}
	elsif ( $cat eq 'ALBUM' ) {
		return Plugins::Deezer::Plugin::renderItem($client, {
			type => 'album', id => $e->{ALB_ID}, title => $e->{ALB_TITLE},
			artist => { name => $e->{ART_NAME} },
			md5_image => $e->{ALB_PICTURE}, picture_type => 'cover',
		}, { addArtistToTitle => 1 });
	}
	elsif ( $cat eq 'PLAYLIST' ) {
		return Plugins::Deezer::Plugin::renderItem($client, {
			type => 'playlist', id => $e->{PLAYLIST_ID}, title => $e->{TITLE},
			creator => { id => $e->{PARENT_USER_ID} }, user => { name => $e->{PARENT_USERNAME} },
			md5_image => $e->{PLAYLIST_PICTURE}, picture_type => $e->{PICTURE_TYPE} || 'playlist',
		});
	}
	elsif ( $cat eq 'TRACK' ) {
		my ($track) = @{Plugins::Deezer::Custom::_cacheTrackMetadata([$e])};
		return Plugins::Deezer::Plugin::renderItem($client, $track, { addArtistToTitle => 1 });
	}
	elsif ( $cat eq 'EPISODE' ) {
		my ($episode) = @{Plugins::Deezer::Custom::_cacheEpisodeMetadata([$e])};
		return Plugins::Deezer::Plugin::renderItem($client, $episode);
	}

	# LIVESTREAM and SHOW are already handled for gw entries
	return Plugins::Deezer::Custom::_renderItem($client, $e);
}

1;
