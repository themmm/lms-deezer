#!/usr/bin/perl
# Regression check for Playable tracks in playlists and albums (fork #19, #20, ADR 0002): runs the
# plugin's own Plugins::Deezer::API::Async->playlistTracks and ->albumTracks with both network
# adapters stubbed: _get (public API) returns a playlist shaped like "Love Machine" and an album
# with the same tracks, gwCall (gw-light song.getListData) returns RIGHTS
# and FALLBACK per track, fails, or is never reached for an account without an ARL.
#   - with a gw answer, a track is listed if it has RIGHTS or a FALLBACK, whatever readable says
#   - without a gw answer (no ARL, failed request, error answer) readable decides for playlists and
#     every track stays listed for albums; never an empty list
#   - one gw request covers the whole playlist
#   - a track that only plays via its FALLBACK shows the FALLBACK's cover, also after the metadata
#     refresh at playback (cacheTrackMetadata on a /track/{id} answer)
# No LMS needed: the LMS modules API.pm and API/Async.pm load are stubbed.
# usage: perl dev/playable-tracks-test.pl [plugin dir]    (default: dev/plugin)
# exit 0 = all cases pass, 1 = a case failed, 2 = the plugin could not be loaded
use strict;
use warnings;
use File::Basename qw(dirname);
use File::Spec;
use JSON::PP ();

my $dir;
BEGIN { $dir = File::Spec->rel2abs(shift // dirname(__FILE__) . '/plugin') }

use constant PLACEHOLDER => 'plugins/Deezer/html/deezer.png';
use constant EMPTY       => 'd41d8cd98f00b204e9800998ecf8427e';    # Deezer's "no image"
use constant OWN_COVER   => '896e9bf452c6942ee9c04cf4bec6467d';
use constant DEAD_COVER  => '5f7e2c0b1a9d4e3f8a6b7c5d4e3f2a1b';    # removed image, CDN redirects to EMPTY
use constant FB_COVER_1  => '38bc36ecd969f166a55a7e630bbaa3aa';
use constant FB_COVER_2  => 'cff936461f2a3b4c5d6e7f8091a2b3c4';

our (%CACHE, $ACCOUNTS, @GW_CALLS, $GW);

BEGIN {
	no strict 'refs';
	*{'main::SCANNER'} = sub () { 0 };
	*{"main::$_"} = sub () { 0 } for qw(INFOLOG DEBUGLOG ISWINDOWS);
	my $exportTo = sub { my ($name, $sub) = @_; sub { *{ caller() . "::$name" } = $sub } };
	%INC = (%INC, map { $_ => __FILE__ } qw(Exporter/Lite.pm Async/Util.pm Data/URIEncode.pm
		JSON/XS/VersionOneAndTwo.pm Slim/Utils/Accessor.pm Slim/Utils/Cache.pm Slim/Utils/Log.pm
		Slim/Utils/Prefs.pm Slim/Utils/Strings.pm Slim/Networking/SimpleAsyncHTTP.pm Slim/Networking/Async/HTTP.pm));
	# Exporter::Lite: exports the names a module asks for
	*{'Exporter::Lite::import'} = sub {
		*{ caller() . '::import' } = sub { my ($from, @names) = @_; my $to = caller; *{"${to}::$_"} = \&{"${from}::$_"} for @names };
	};
	*{'Data::URIEncode::import'} = $exportTo->(complex_to_query => sub { '' });
	*{'JSON::XS::VersionOneAndTwo::import'} = sub {
		my $to = caller; *{"${to}::$_"} = \&{"JSON::PP::$_"} for qw(encode_json decode_json);
		*{"${to}::from_json"} = sub { JSON::PP::decode_json($_[0]) }; *{"${to}::to_json"} = sub { JSON::PP::encode_json($_[0]) };
	};
	*{'Slim::Utils::Accessor::new'} = sub { bless {}, ref $_[0] || $_[0] };
	*{'Slim::Utils::Accessor::mk_accessor'} = sub {
		my ($class, $type, @names) = @_;
		for my $name (@names) { *{"${class}::$name"} = sub { $_[0]->{$name} = $_[1] if @_ > 1; $_[0]->{$name} } }
	};
	*{'Slim::Utils::Cache::new'} = sub { bless {}, 'Slim::Utils::Cache' };
	*{'Slim::Utils::Cache::get'} = sub { $CACHE{$_[1]} };
	*{'Slim::Utils::Cache::set'} = sub { $CACHE{$_[1]} = $_[2] };
	*{'Slim::Utils::Cache::remove'} = sub { delete $CACHE{$_[1]} };
	*{'Slim::Utils::Log::import'} = $exportTo->(logger => sub { bless {}, 'Stub' });
	*{'Slim::Utils::Prefs::import'} = $exportTo->(preferences => sub { bless {}, 'Prefs' });
	*{'Prefs::get'} = sub { $_[1] eq 'accounts' ? $ACCOUNTS : undef };
	*{'Prefs::set'} = sub {};
	*{'Slim::Utils::Strings::import'} = $exportTo->(string => sub { $_[0] });
	*{"Slim::Utils::Timers::$_"} = sub {} for qw(killTimers setTimer);
	*{'Plugins::Deezer::Plugin::_pluginDataFor'} = sub { PLACEHOLDER };
	*{'Stub::AUTOLOAD'} = sub {};
}

eval {
	require "$dir/API.pm";
	$INC{'Plugins/Deezer/API.pm'} = "$dir/API.pm";
	require "$dir/API/Async.pm";
	1;
} or do { print "VERDICT: inconclusive (cannot load the plugin from $dir: $@)\n"; exit 2 };

# --- the network adapters ----------------------------------------------------------------------

# public API: playlist "Love Machine" as /playlist/{id}/tracks answers it (only the fields used here)
my $track = sub {
	my ($id, $title, $readable, $md5) = @_;
	return { id => $id, type => 'track', title => $title, readable => $readable ? JSON::PP::true : JSON::PP::false,
		duration => 200, md5_image => $md5 // OWN_COVER, album => { id => 1, title => 'Album', md5_image => $md5 // OWN_COVER } };
};
my @LOVE_MACHINE = (
	$track->(661301,    'Lovemachine',         1),
	$track->(2540822,   'On My Way In L.A.',   1),             # readable, but neither RIGHTS nor FALLBACK
	$track->(145534376, 'Waiting For A Train', 0, EMPTY),      # plays via FALLBACK, no image of its own
	$track->(916462,    "Fool's Overture",     0, DEAD_COVER), # plays via FALLBACK, removed image
	$track->(3083376,   'Unplayable',          0),             # neither RIGHTS nor FALLBACK
	$track->(999001,    'Not answered, readable', 1),          # gw leaves it out: readable decides
	$track->(999002,    'Not answered, not readable', 0),
	{ id => -42, type => 'track', title => 'My upload', duration => 200 },    # user-uploaded
	{ id => 7, type => 'podcast', title => 'not a track' },
);
my %GW_ANSWER = (
	661301    => { SNG_ID => '661301',    RIGHTS => { STREAM_ADS_AVAILABLE => JSON::PP::true } },
	2540822   => { SNG_ID => '2540822',   RIGHTS => {} },
	145534376 => { SNG_ID => '145534376', RIGHTS => {}, FALLBACK => { SNG_ID => '3783857672', ALB_PICTURE => FB_COVER_1 } },
	916462    => { SNG_ID => '916462',    RIGHTS => {}, FALLBACK => { SNG_ID => '2161364', ALB_PICTURE => FB_COVER_2 } },
	3083376   => { SNG_ID => '3083376',   RIGHTS => {} },
	999002    => undef,
);
our @PLAYLIST = @LOVE_MACHINE;
# album tracks (/album/{id}/tracks): the same mix, but albums never filtered on readable
my @ALBUM_TRACKS = grep { $_->{id} > 0 && $_->{type} eq 'track' } @LOVE_MACHINE;
our @ALBUM = @ALBUM_TRACKS;
our $ALBUM_FAILS;

{
	no warnings qw(redefine once);
	*Plugins::Deezer::API::Async::_get = sub {
		my ($self, $url, $cb) = @_;
		# a fresh copy per request, like a real answer: the plugin writes into the track hashes
		my $answer = sub { JSON::PP::decode_json(JSON::PP::encode_json($_[0])) };
		$cb->(
			$url =~ m{^/playlist/\d+/tracks$} ? $answer->({ data => \@PLAYLIST }) :
			$url =~ m{^/album/\d+/tracks$}    ? ($ALBUM_FAILS ? undef : $answer->({ data => \@ALBUM })) :
			$url =~ m{^/album/(\d+)$}         ? { id => $1, title => 'Album', md5_image => OWN_COVER } :
			undef
		);
	};
	# refreshArl: deezer.getUserData, then user.getArl, which hands out the ARL for the account
	*Plugins::Deezer::API::Async::_ajax = sub {
		my ($self, $cb, $params) = @_;
		$cb->({ results => $params->{method} eq 'user.getArl' ? 'fakeArlFromRefresh' : { checkForm => 'x', SESSION_ID => 'y' } });
	};
	*Plugins::Deezer::API::Async::gwCall = sub {
		my ($self, $cb, $args, $content) = @_;
		push @GW_CALLS, { method => $args->{method}, ids => [ @{ $content->{sng_ids} || [] } ] };
		$GW->($cb, $content->{sng_ids} || []);
	};
}
my %gw = (
	answers => sub { my ($cb, $ids) = @_; $cb->({ results => { data => [ grep { $_ } map { $GW_ANSWER{$_} } @$ids ] } }) },
	fails   => sub { $_[0]->() },
	error   => sub { $_[0]->({ error => { VALID_TOKEN_REQUIRED => 'Invalid CSRF token' }, results => {} }) },
	# PHP encodes an empty array as [], so an error answer can carry a list instead of a hash
	errorList => sub { $_[0]->({ error => { VALID_TOKEN_REQUIRED => 'Invalid CSRF token' }, results => [] }) },
);

# --- accounts ----------------------------------------------------------------------------------

$ACCOUNTS = { 1001 => { arl => 'fakeArl' }, 1002 => {} };
Plugins::Deezer::API::Async::refreshArl(1001);
my $withArl    = Plugins::Deezer::API::Async->new({ userId => 1001 });
my $withoutArl = Plugins::Deezer::API::Async->new({ userId => 1002 });

my $list = sub {
	my ($api, $gw, @playlist) = @_;
	%CACHE = (); @GW_CALLS = (); $GW = $gw{$gw}; @PLAYLIST = @playlist ? @playlist : @LOVE_MACHINE;
	my $result;
	eval { $api->playlistTracks(sub { $result = shift }, 13715702701); 1 } or $result = [ { id => "died: $@" } ];
	return $result || [];
};
my $album = sub {
	my ($api, $gw, @tracks) = @_;
	%CACHE = (); @GW_CALLS = (); $GW = $gw{$gw}; @ALBUM = @tracks ? @tracks : @ALBUM_TRACKS;
	my ($result, $total);
	eval { $api->albumTracks(sub { ($result, $total) = @_ }, 248956); 1 } or $result = [ { id => "died: $@" } ];
	return wantarray ? ($result || [], $total) : $result || [];
};
my $ids = sub { join ' ', map { $_->{id} } @{ $_[0] } };
my $cover = sub { my ($items, $id) = @_; my ($t) = grep { $_->{id} == $id } @$items; $t ? $t->{cover} // '' : 'missing' };
my $shows = sub { my ($url, $md5) = @_; index($url // '', $md5) >= 0 };

# --- cases: [ name, check, what was seen ] -----------------------------------------------------

my @cases;
my $case = sub { my ($name, $ok, $seen) = @_; push @cases, [ $name, $ok, $seen ] };
my $byReadable = '661301 2540822 999001 -42';

my $r = $list->($withoutArl, 'answers');
$case->('without an ARL: readable decides, no gw request', $ids->($r) eq $byReadable && !@GW_CALLS,
	$ids->($r) . ', gw requests: ' . @GW_CALLS);

$r = $list->($withArl, 'fails');
$case->('gw request fails: readable decides', $ids->($r) eq $byReadable, $ids->($r));

$r = $list->($withArl, 'error');
$case->('gw answers with an error: readable decides', $ids->($r) eq $byReadable, $ids->($r));

$r = $list->($withArl, 'errorList');
$case->('gw answers with an error and results []: readable decides', $ids->($r) eq $byReadable, $ids->($r));

$r = $list->($withArl, 'fails', grep { $_->{id} != -42 } @LOVE_MACHINE);
$case->('gw request fails: the list is not empty', scalar @$r, scalar(@$r) . ' tracks');

$r = $list->($withArl, 'answers');
$case->('gw answers: RIGHTS or FALLBACK decide', $ids->($r) eq '661301 145534376 916462 999001 -42', $ids->($r));
$case->('Fallback-only track without image: Fallback cover', $shows->($cover->($r, 145534376), FB_COVER_1), $cover->($r, 145534376));
$case->('Fallback-only track, removed image: Fallback cover', $shows->($cover->($r, 916462), FB_COVER_2), $cover->($r, 916462));
$case->('track with RIGHTS keeps its own cover', $shows->($cover->($r, 661301), OWN_COVER), $cover->($r, 661301));

# metadata refresh at playback: /track/{id} brings the original track's image again
my ($refreshed) = @{ Plugins::Deezer::API->cacheTrackMetadata([ $track->(145534376, 'Waiting For A Train', 0, EMPTY) ]) };
$case->('metadata refresh keeps the Fallback cover', $shows->($refreshed->{cover}, FB_COVER_1), $refreshed->{cover});

my @big = map { $track->(5000000 + $_, "Track $_", 1) } 1 .. 1200;
$r = $list->($withArl, 'answers', @big);
$case->('one gw request for 1200 tracks', @GW_CALLS == 1 && @{ $GW_CALLS[0]{ids} } == 1200 && $GW_CALLS[0]{method} eq 'song.getListData',
	scalar(@GW_CALLS) . ' requests, ' . join('+', map { scalar @{ $_->{ids} } } @GW_CALLS) . ' ids');

# albums (fork #20): the same check, but without a gw answer every track stays listed
my $allAlbumTracks = join ' ', map { $_->{id} } @ALBUM_TRACKS;

$r = $album->($withArl, 'answers');
$case->('album, gw answers: RIGHTS or FALLBACK decide', $ids->($r) eq '661301 145534376 916462 999001 999002', $ids->($r));
$case->('album, Fallback-only track: Fallback cover', $shows->($cover->($r, 145534376), FB_COVER_1), $cover->($r, 145534376));

# getAlbum says "no playable tracks" only for an album that has tracks, not for a failed request
my $total;
($r, $total) = $album->($withArl, 'answers', grep { $_->{id} == 2540822 || $_->{id} == 3083376 } @ALBUM_TRACKS);
$case->('album without a Playable track: empty list', !@$r, $ids->($r));
$case->('album without a Playable track: reports its 2 tracks', ($total // '') eq '2', $total // 'undef');

{
	local $ALBUM_FAILS = 1;
	($r, $total) = $album->($withArl, 'answers');
	$case->('album request fails: empty list, no tracks reported', !@$r && !$total, $ids->($r) . ', total ' . ($total // 'undef'));
}

$r = $album->($withoutArl, 'answers');
$case->('album without an ARL: every track, no gw request', $ids->($r) eq $allAlbumTracks && !@GW_CALLS,
	$ids->($r) . ', gw requests: ' . @GW_CALLS);

for my $how (qw(fails error errorList)) {
	$r = $album->($withArl, $how);
	$case->("album, gw $how: every track", $ids->($r) eq $allAlbumTracks, $ids->($r));
}

my $fail = 0;
for (@cases) {
	my ($name, $ok, $seen) = @$_;
	printf "%-52s %s\n", $name, $ok ? 'ok' : "FAIL ($seen)";
	$fail ||= !$ok;
}
print $fail ? "VERDICT: RED\n" : "VERDICT: green\n";
exit($fail ? 1 : 0);
