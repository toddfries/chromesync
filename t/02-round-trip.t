#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 2;
use JSON;
use File::Temp qw(tempdir);

my $dir = tempdir(CLEANUP => 1);

system("./export_bookmarks.pl --profile 0 --output $dir/original.b",
       "t/fixtures/chrome-default-Bookmarks.json") == 0 or die;

system("./import_bookmarks.pl --input $dir/original.b --output $dir/reconstructed.json") == 0 or die;

my $orig_json = decode_json(do { local $/; open my $f, '<', "t/fixtures/chrome-default-Bookmarks.json"; <$f> });
my $new_json  = decode_json(do { local $/; open my $f, '<', "$dir/reconstructed.json"; <$f> });

# Remove fields that legitimately change
delete $orig_json->{roots}{$_}{date_modified} for keys %{$orig_json->{roots}};
delete $new_json->{roots}{$_}{date_modified}  for keys %{$new_json->{roots}};

is_deeply($new_json, $orig_json, "Full round-trip preserves all data (except date_modified)");