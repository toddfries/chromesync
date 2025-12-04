#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 6;
use File::Temp qw(tempdir);
use FindBin qw($Bin);

my $merge = "$Bin/../bookmarks.pl --mode merge";
my $dir = tempdir(CLEANUP => 1);

sub write_file {
    open my $f, '>', $_[0] or die "write $_[0]: $!";
    print $f $_[1];
    close $f;
}
sub read_file {
    local $/; open my $f, '<', $_[0] or die "read $_[0]: $!"; return <$f>;
}

write_file("$dir/up.b",   "url: guid=123, name=Grok, parent_guid=root, url=https://x.com/i/grok\n");
write_file("$dir/loc.b",  "url: guid=123, name=Grok Chat, parent_guid=root, url=https://x.com/i/grok?focus=1\n");

# Test 1: Choose upstream (1)
system($^X, $merge, '--upstream', "$dir/up.b", '--local', "$dir/loc.b", '--output', "$dir/o1.b", '--non-interactive', '--answer', '1') == 0 or die "merge1 failed";
like(read_file("$dir/o1.b"), qr/x\.com/i/grok(?!\?focus), "choose upstream keeps old URL");

# Test 2: Choose local (2)
system($^X, $merge, '--upstream', "$dir/up.b", '--local', "$dir/loc.b", '--output', "$dir/o2.b", '--non-interactive', '--answer', '2') == 0 or die "merge2 failed";
like(read_file("$dir/o2.b"), qr/\?focus=1/, "choose local takes new URL");
like(read_file("$dir/o2.b"), qr/Grok Chat/, "choose local takes new name");

# Test 3: Auto-add new from local
write_file("$dir/new.b", "url: guid=NEW, name=New Site, parent_guid=root, url=https://example.com\n");
system($^X, $merge, '--upstream', "$dir/up.b", '--local', "$dir/new.b", '--output', "$dir/o3.b", '--non-interactive') == 0 or die "merge3 failed";
like(read_file("$dir/o3.b"), qr/example\.com/, "new local bookmark auto-added");

# Test 4: Output sorted
my @lines = split /\n/, read_file("$dir/o3.b");
is_deeply([sort @lines], [@lines], "merge output globally sorted");

# Test 5: Default to upstream (no --answer)
system($^X, $merge, '--upstream', "$dir/up.b", '--local', "$dir/loc.b", '--output', "$dir/o4.b", '--non-interactive') == 0 or die "merge4 failed";
like(read_file("$dir/o4.b"), qr/x\.com/i/grok(?!\?focus), "default chooses upstream");
