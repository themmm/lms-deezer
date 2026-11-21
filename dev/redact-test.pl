#!/usr/bin/perl
# Regression check for _redact in API/Async.pm (fork #9, #13): runs the plugin's own _redact and
# _dump on fake secrets in every shape they reach the log. Prints case names only, never values.
# usage: perl dev/redact-test.pl [path/to/API/Async.pm]    (default: dev/plugin/API/Async.pm)
# exit 0 = all cases pass, 1 = a case failed, 2 = _redact not found in the file
use strict;
use warnings;
use Data::Dump;
use File::Basename qw(dirname);

my $file = shift // dirname(__FILE__) . '/plugin/API/Async.pm';
open my $fh, '<', $file or die "$file: $!\n";
my $src = do { local $/; <$fh> };
my ($code) = $src =~ /^(my \$SECRET_KEYS = .*?^sub _dump \{.*?\}\n)/ms
	or do { print "VERDICT: inconclusive (_redact not found in $file)\n"; exit 2 };
eval "package R; $code; 1" or die $@;

my $arl = join '', map { sprintf '%x', $_ % 16 } 1 .. 192;
my @cases = (
	[ 'hash dump: SESSION_ID, license_token', R::_dump({ SESSION_ID => 'sessFAKE1234567890abcd', license_token => 'licFAKE1234567890abcd' }), [qw(sessFAKE licFAKE)] ],
	[ 'hash dump: rotated ARL', R::_dump({ results => $arl }), [ substr($arl, 0, 40) ] ],
	[ 'query string: api_token, sid', R::_redact("GET ?method=x&api_token=tokFAKE1234567890&sid=sidFAKE1234567890 "), [qw(tokFAKE sidFAKE)] ],
	[ 'cookie header: arl, sid', R::_dump({ Cookie => "arl=$arl; sid=sidFAKE1234567890" }), [ substr($arl, 0, 40), 'sidFAKE' ] ],
	[ 'dumped JSON string: license_token', R::_dump('{"license_token":"licFAKE1234567890abcd","track_tokens":["x"]}'), ['licFAKE'] ],
	[ 'dumped JSON string: checkForm, USER_TOKEN', R::_dump('{"checkForm":"cfFAKE1234567890","USER_TOKEN":"utFAKE1234567890"}'), [qw(cfFAKE utFAKE)] ],
);
my @keep = (
	[ 'non-secret fields stay readable', R::_dump({ USER_ID => 123456, OFFER_NAME => 'Deezer Family' }), [ '123456', 'Deezer Family' ] ],
);

my $fail = 0;
for (@cases) {
	my ($name, $out, $secrets) = @$_;
	my $leak = grep { index($out, $_) >= 0 } @$secrets;
	printf "%-48s %s\n", $name, $leak ? 'LEAK' : 'ok';
	$fail ||= $leak;
}
for (@keep) {
	my ($name, $out, $want) = @$_;
	my $lost = grep { index($out, $_) < 0 } @$want;
	printf "%-48s %s\n", $name, $lost ? 'MASKED' : 'ok';
	$fail ||= $lost;
}
print $fail ? "VERDICT: RED\n" : "VERDICT: green\n";
exit($fail ? 1 : 0);
