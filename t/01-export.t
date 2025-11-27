#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 3;
use File::Temp qw(tempfile);
use IPC::Run3;

my $fixture = "t/fixtures/chrome-default-Bookmarks.json";
my ($out_fh, $out_file) = tempfile(UNLINK => 1);

run3 ['./export_bookmarks.pl', '--profile', '0', '--output', $out_file],
    \$fixture, \undef, \undef;

my $got      = do { local $/; open my $fh, '<', $out_file; <$fh> };
my $expected = do { local $/; open my $fh, '<', "t/fixtures/expected-default.txt"; <$fh> };

is($got, $expected, "export produces exact expected text format");

# Run twice — must be deterministic (no timestamps leaking!)
seek $out_fh, 0, 0; truncate $out_fh, 0;
run3 ['./export_bookmarks.pl', '--profile', '0', '--output', $out_file],
    \$fixture, \undef, \undef;

$got = do { local $/; open my $fh, '<', $out_file; <$fh> };
is($got, $expected, "export is deterministic (second run)");

# Also test that lines are sorted (your script claims to sort)
my @lines = split /\n/, $got;
my @sorted = sort @lines;
is_deeply(\@lines, \@sorted, "export output is globally sorted");