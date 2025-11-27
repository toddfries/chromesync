#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 6;
use File::Temp qw(tempdir);
 FindBin qw($Bin);
my $merge = "$Bin/../merge_bookmarks.pl";

my $dir = tempdir(CLEANUP => 1);

# upstream: old URL
write("$dir/up.b", <<UP);
url: guid=11111111-1111-1111-1111-111111111111, name=Grok, parent_guid=root, url=https://x.com/i/grok
UP

# local: fixed URL + better name
write("$dir/loc.b", <<LOC);
url: guid=11111111-1111-1111-1111-111111111111, name=Grok Chat, parent_guid=root, url=https://x.com/i/grok?focus=1
LOC

# Test 1: always pick upstream
run("$merge --upstream $dir/up.b --local $dir/loc.b --output $dir/out1.b --non-interactive --answer 1");
my $out1 = read("$dir/out1.b");
like($out1, qr/x\.com\/i\/grok$/, "upstream URL preserved when chosen");

# Test 2: always pick local
run("$merge --upstream $dir/up.b --local $dir/loc.b --output $dir/out2.b --non-interactive --answer 2");
my $out2 = read("$dir/out2.b");
like($out2, qr/\?focus=1/, "local URL wins when chosen");
like($out2, qr/Grok Chat/, "local name wins");

# Test 3: new bookmark from local only
write("$dir/local-new.b", "url: guid=new-123, name=New Site, parent_guid=root, url=https://example.com\n");
run("$merge --upstream $dir/up.b --local $dir/local-new.b --output $dir/out3.b --non-interactive");
like(read("$dir/out3.b"), qr/example\.com/, "new bookmark auto-added");

# Test 4: output is sorted
my @lines = split /\n/, read("$dir/out3.b");
is_deeply([sort @lines], [@lines], "merge output is globally sorted");

# Test 5: no conflict → default to upstream
run("$merge --upstream $dir/up.b --local $dir/loc.b --output $dir/out4.b --non-interactive");
like(read("$dir/out4.b"), qr/x\.com\/i\/grok$/, "no --answer defaults to upstream");

sub write { open my $f, '>', $_[0]; print $f $_[1]; close $f }
sub read  { local $/; open my $f, '<', $_[0]; <$f> }
sub run   { system($^X, split ' ', $_[0]) == 0 or die "FAILED: $_[0]" }