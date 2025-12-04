#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 2;
use JSON;
use File::Temp qw(tempdir);
use FindBin qw($Bin);

my $dir = tempdir(CLEANUP => 1);
my $home = "$dir/fakehome";
mkdir $home or die;
mkdir "$home/.config/chromium/Default" or die;
open my $fh, '>', "$home/.config/chromium/Default/Bookmarks" or die $!;
my $content = do { local $/; open my $f, '<', "$Bin/01-export.t"; <$f> };
my ($json) = $content =~ /<<'JSON';\n(.*?\n\})\nJSON/s;
print $fh $json;
close $fh;

local $ENV{HOME} = $home;

my $export = "$Bin/../bookmarks.pl --mode export";
my $import = "$Bin/../bookmarks.pl --mode import";
system($^X, $export, '--profile', '0', '--output', "$dir/flat.b") == 0 or die "export failed";
system($^X, $import, '--input', "$dir/flat.b", '--output', "$dir/new.json") == 0 or die "import failed";

my $orig = decode_json($json);
my $new  = decode_json(do { local $/; open my $f, '<', "$dir/new.json"; <$f> });

delete $orig->{roots}{$_}{date_modified} for keys %{$orig->{roots}};
delete $new->{roots}{$_}{date_modified}  for keys %{$new->{roots}};
for my $r (values %{$new->{roots}}) {
    for my $c (@{$r->{children} || []}) {
        delete $c->{order};
        delete $c->{parent_guid};
        delete $c->{meta_info} if $c->{meta_info} && $c->{meta_info}{power_bookmark_meta} eq '';
    }
}

is_deeply($new->{roots}, $orig->{roots}, "round-trip preserves structure (ignoring timestamps/meta)");

system($^X, $export, '--profile', '0', '--output', "$dir/flat2.b") == 0 or die "second export failed";
my $f1 = do { local $/; open my $f, '<', "$dir/flat.b"; <$f> };
my $f2 = do { local $/; open my $f, '<', "$dir/flat2.b"; <$f> };
is($f1, $f2, "round-trip flat file is identical");
