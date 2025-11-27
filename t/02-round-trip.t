#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 2;
use JSON;
use File::Temp qw(tempdir);
 FindBin qw($Bin);

my $dir = tempdir(CLEANUP => 1);
my $export = "$Bin/../export_bookmarks.pl";
my $import = "$Bin/../import_bookmarks.pl";

# Use same fake JSON as 01-export.t
open my $fh, '<', "$Bin/01-export.t" or die;
my $content = do { local $/; <$fh> };
my ($json) = $content =~ /<<'JSON';\n(.*?)\nJSON/s;

open my $fj, '>', "$dir/Bookmarks"; print $fj $json; close $fj;
$ENV{HOME} = $dir;

system($^X, $export, '--profile', '0', '--output', "$dir/flat.b") == 0 or die;
system($^X, $import, '--input', "$dir/flat.b", '--output', "$dir/new.json") == 0 or die;

my $orig = decode_json($json);
my $new  = decode_json(do { local $/; open my $f, '<', "$dir/new.json"; <$f> });

# Clean up expected differences
delete @{$orig->{roots}}{qw(date_modified)};
delete @{$new->{roots}}{qw(date_modified)};
for my $root (values %{$new->{roots}}) {
    delete $root->{children}[$_]{order} for 0..$#{$root->{children}||[]};
    delete $root->{children}[$_]{parent_guid} for 0..$#{$root->{children}||[]};
}

is_deeply($new->{roots}, $orig->{roots}, "round-trip preserves all roots and structure")
    or diag explain $new;

system($^X, $export, '--profile', '0', '--output', "$dir/flat2.b") == 0 or die;
my $f1 = do { local $/; open my $f, '<', "$dir/flat.b";  <$f> };
my $f2 = do { local $/; open my $f, '<', "$dir/flat2.b"; <$f> };
is($f1, $f2, "exporting imported JSON gives identical flat file");