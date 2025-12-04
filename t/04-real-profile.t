#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use File::Copy;

# Only run if real fixture exists
if (-f "t/fixtures/real-default.b") {
    plan tests => 2;
    system("./bookmarks.pl --mode export --profile 0 --output /tmp/real-test.b") == 0 or die;
    my $real = do { local $/; open my $f, '<', "t/fixtures/real-default.b"; <$f> };
    my $now  = do { local $/; open my $f, '<', "/tmp/real-test.b";       <$f> };
    is($real, $now, "export matches previously committed real-default.b");
    ok(-s "/tmp/real-test.b" > 10000, "real export is big and healthy");
} else {
    plan skip_all => "no real fixture yet — run: perl bookmarks.pl --mode export --profile 0 --output t/fixtures/real-default.b";
}
