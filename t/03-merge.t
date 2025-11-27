#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 6;
use File::Temp qw(tempdir);
use FindBin qw($Bin);

my $merge = "$Bin/../merge_bookmarks.pl";
my $dir = tempdir(CLEANUP => 1);

sub w { open my $f,'>',$_[0]; print $f $_[1] }
sub r { local $/; open my $f,'<',$_[0]; <$f> }

w("$dir/up.b",  "url: guid=123, name=Grok, parent_guid=root, url=https://x.com/i/grok\n");
w("$dir/loc.b", "url: guid=123, name=Grok Chat, parent_guid=root, url=https://x.com/i/grok?focus=1\n");

system("$^X $merge --upstream $dir/up.b --local $dir/loc.b --output $dir/o1.b --non-interactive --answer 1") == 0 or die;
like(r("$dir/o1.b"), qr/x\.com\/i\/grok$/, "answer 1 keeps upstream/);

system("$^X $merge --upstream $dir/up.b --local $dir/loc.b --output $dir/o2.b --non-interactive --answer 2") == 0 or die;
like(r("$dir/o2.b"), qr/\?focus=1/, "answer 2 takes local URL");
like(r("$dir/o2.b"), qr/Grok Chat/, "answer 2 takes local name");

w("$dir/new.b", "url: guid=NEW, name=New Site, parent_guid=root, url=https://example.com\n");
system("$^X $merge --upstream $dir/up.b --local $dir/new.b --output $dir/o3.b --non-interactive") == 0 or die;
like(r("$dir/o3.b"), qr/example\.com/, "new bookmark added");

my @lines = split /\n/, r("$dir/o3.b");
is_deeply([sort @lines], [@lines], "output sorted");

system("$^X $merge --upstream $dir/up.b --local $dir/loc.b --output $dir/o4.b --non-interactive") == 0 or die;
like(r("$dir/o4.b"), qr/x\.com\/i\/grok$/, "no answer = upstream");
