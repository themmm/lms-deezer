#!/usr/bin/perl
# Regression check for Deezer's empty image (fork #15): runs the plugin's own
# Plugins::Deezer::API->getImageUrl on items shaped like public API answers. Deezer marks "no image"
# with the MD5 of an empty string; a cover built from it is a blank image.
#   - an item whose image is that marker counts as having no image of its own
#   - a track without an image of its own gets its album's cover
#   - if the album's cover is the marker too, the item gets the placeholder (or nothing without one)
# No LMS needed: the LMS modules API.pm loads are stubbed.
# usage: perl dev/empty-image-test.pl [path/to/API.pm]    (default: dev/plugin/API.pm)
# exit 0 = all cases pass, 1 = a case failed, 2 = API.pm could not be loaded
use strict;
use warnings;
use File::Basename qw(dirname);
use File::Spec;

# absolute, so that require does not search @INC for a relative path
my $file;
BEGIN { $file = File::Spec->rel2abs(shift // dirname(__FILE__) . '/plugin/API.pm') }

use constant PLACEHOLDER => 'plugins/Deezer/html/deezer.png';
use constant EMPTY => 'd41d8cd98f00b204e9800998ecf8427e';
use constant OWN_IMAGE   => '896e9bf452c6942ee9c04cf4bec6467d';
use constant ALBUM_IMAGE => '38bc36ecd969f166a55a7e630bbaa3aa';
use constant ALBUM_COVER => 'https://api.deezer.com/album/301217/image';    # redirects to the album's image

BEGIN {
	no strict 'refs';
	*{'main::SCANNER'} = sub () { 0 };
	*{"main::$_"} = sub () { 0 } for qw(INFOLOG DEBUGLOG ISWINDOWS);
	my $exportTo = sub { my ($name, $sub) = @_; sub { *{ caller() . "::$name" } = $sub } };
	%INC = (%INC, map { $_ => __FILE__ } qw(Exporter/Lite.pm Slim/Utils/Cache.pm Slim/Utils/Log.pm Slim/Utils/Prefs.pm));
	*{'Exporter::Lite::import'} = sub { *{ caller() . '::import' } = sub {} };
	*{'Slim::Utils::Cache::new'} = sub { bless {}, 'Slim::Utils::Cache' };
	*{'Slim::Utils::Log::import'} = $exportTo->(logger => sub { bless {}, 'Stub' });
	*{'Slim::Utils::Prefs::import'} = $exportTo->(preferences => sub { bless {}, 'Stub' });
	*{'Plugins::Deezer::Plugin::_pluginDataFor'} = sub { PLACEHOLDER };
}

eval { require $file; 1 } or do { print "VERDICT: inconclusive (cannot load $file: $@)\n"; exit 2 };

my $cdn = sub { "https://cdn-images.dzcdn.net/images/$_[0]/$_[1]/500x500-000000-80-0-0.jpg" };
my $track = sub {
	my ($own, $album) = @_;
	return {
		id => 3121382, type => 'track', title => 'Coffee In The Pot', duration => 180, md5_image => $own,
		album => { id => 301217, type => 'album', cover => ALBUM_COVER,
			cover_big => $cdn->(cover => $album), md5_image => $album },
	};
};
my $album = sub {
	my ($md5) = @_;
	return { id => 466055, type => 'album', title => 'Lazy - Original', md5_image => $md5,
		cover => 'https://api.deezer.com/album/466055/image', cover_big => $cdn->(cover => $md5) };
};
my $playlist = sub {
	my ($md5) = @_;
	return { id => 13715702701, type => 'playlist', title => 'Love Machine', md5_image => $md5,
		picture_type => 'playlist', picture => 'https://api.deezer.com/playlist/13715702701/image',
		picture_big => $cdn->(playlist => $md5) };
};
# artists have no md5_image, only picture URLs
my $artist = sub {
	my ($md5) = @_;
	return { id => 12332, type => 'artist', name => 'Flash and the Pan', picture_type => 'artist',
		picture => 'https://api.deezer.com/artist/12332/image',
		picture_big => $cdn->(artist => $md5), picture_medium => $cdn->(artist => $md5) };
};

# [ name, item, usePlaceholder, check of the returned image, what is expected ]
my $shows = sub { my $md5 = shift; sub { ($_[0] // '') =~ /\b$md5\b/ } };
my $isPlaceholder = sub { ($_[0] // '') eq PLACEHOLDER };
my $isNothing = sub { !$_[0] };
my @cases = (
	[ 'track with its own image',                        $track->(OWN_IMAGE, ALBUM_IMAGE),    1, $shows->(OWN_IMAGE),   'own image' ],
	[ 'track without image, album has a cover',          $track->(EMPTY, ALBUM_IMAGE),        1, sub { $shows->(ALBUM_IMAGE)->(@_) || ($_[0] // '') eq ALBUM_COVER }, "album's cover" ],
	[ 'track and album without image',                   $track->(EMPTY, EMPTY),              1, $isPlaceholder,        'placeholder' ],
	[ 'track and album without image, no placeholder',   $track->(EMPTY, EMPTY),              0, $isNothing,            'no image' ],
	[ 'album with its own image',                        $album->(ALBUM_IMAGE),               1, $shows->(ALBUM_IMAGE), 'own image' ],
	[ 'album without image',                             $album->(EMPTY),                     1, $isPlaceholder,        'placeholder' ],
	[ 'playlist with its own image',                     $playlist->(OWN_IMAGE),              1, $shows->(OWN_IMAGE),   'own image' ],
	[ 'playlist without image',                          $playlist->(EMPTY),                  1, $isPlaceholder,        'placeholder' ],
	[ 'artist with its own image',                       $artist->(OWN_IMAGE),                1, $shows->(OWN_IMAGE),   'own image' ],
	[ 'artist without image',                            $artist->(EMPTY),                    1, $isPlaceholder,        'placeholder' ],
);

my $fail = 0;
for (@cases) {
	my ($name, $item, $usePlaceholder, $check, $want) = @$_;
	my $got = Plugins::Deezer::API->getImageUrl($item, $usePlaceholder ? 'usePlaceholder' : undef);
	my $ok = $check->($got);
	my $shown = !$got ? 'nothing' : $got eq PLACEHOLDER ? 'placeholder' : ($got =~ /([0-9a-f]{32})/) ? ($1 eq EMPTY ? 'EMPTY IMAGE' : substr($1, 0, 8)) : $got;
	printf "%-48s %-5s expected %-14s got %s\n", $name, $ok ? 'ok' : 'FAIL', $want, $shown;
	$fail ||= !$ok;
}
print $fail ? "VERDICT: RED\n" : "VERDICT: green\n";
exit($fail ? 1 : 0);
