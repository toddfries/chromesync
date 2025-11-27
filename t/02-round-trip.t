#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 2;
use JSON;
use File::Temp qw(tempdir);
use FindBin qw($Bin);

my $dir = tempdir(CLEANUP => 1);
mkdir "$dir/.config/chromium/Default" or die;
open my $fh, '>', "$dir/.config/chromium/Default/Bookmarks" or die;
print $fh do { local $/; open my $f, '<', "$Bin/01-export.t"; <$f> =~ /<<'JSON';\n(.*\n\})\nJSON/s; $1 };
close $fh;

local $ENV{HOME} = $dir;

system("$^X $Bin/../export_bookmarks.pl --profile 0 --output $dir/flat.b") == 0 or die;
system("$^X $Bin/../import_bookmarks.pl --input $dir/flat.b --output $dir/new.json") == 0 or die;

my $orig = decode_json(do { local $/; open my $f, '<', "$dir/.config/chromium/Default/Bookmarks"; <$f> });
my $new  = decode_json(do { local $/; open my $f, '<', "$dir/new.json"; <$f> });

delete @{$orig->{roots}}{qw(date_modified)};
delete @{$new->{roots}}{qw(date_modified)};
for my $r (values %{$new->{roots}}) {
    for my $c (@{$r->{children}||[]}) { delete @$c{qw(order parent_guid)}; }
}

is_deeply($new->{roots}, $orig->{roots}, "round-trip perfect");

system("$^X $Bin/../export_bookmarks.pl --profile 0 --output $dir/flat2.b") == 0 or die;
my ($f1,$f2) = map { do { local $/; open my $f,'<',$_; <$f> } } "$dir/flat.b","$dir/flat2.b";
is($f1,$f2,"flat file identical after round-trip");
