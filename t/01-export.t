#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 4;
use FindBin qw($Bin);
use File::Temp qw(tempdir);

my $script = "$Bin/../bookmarks.pl";

my $fake_json = <<'JSON';
{
  "checksum": "fake",
  "roots": {
    "bookmark_bar": { "type":"folder", "guid":"b1", "name":"Bookmarks bar", "children":[
      { "type":"url", "guid":"u1", "name":"Grok", "url":"https://x.com/i/grok" },
      { "type":"folder", "guid":"f1", "name":"AI", "children":[
        { "type":"url", "guid":"u2", "name":"Claude", "url":"https://claude.ai/" }
      ]}
    ]},
    "other":  { "type":"folder", "guid":"b2", "name":"Other bookmarks",  "children":[] },
    "synced": { "type":"folder", "guid":"b3", "name":"Mobile bookmarks", "children":[] }
  },
  "version":1
}
JSON

my $dir = tempdir(CLEANUP => 1);
my $home = "$dir/fakehome";
mkdir $home or die;
mkdir "$home/.config" or die;
mkdir "$home/.config/chromium" or die;
mkdir "$home/.config/chromium/Default" or die;
open my $fh, '>', "$home/.config/chromium/Default/Bookmarks" or die $!;
print $fh $fake_json;
close $fh;

local $ENV{HOME} = $home;

system($^X, $script, '--mode', 'export', '--profile', '0', '--output', "$dir/out.b") == 0
    or die "export failed: $!";

my @got = sort map { chomp; $_ } do { local $/; open my $f, '<', "$dir/out.b"; <$f> =~ /(.*)/gs };

my @exp = sort (
  'folder: guid=b1, name=Bookmarks bar, root=bookmark_bar',
  'folder: guid=f1, name=AI, parent_guid=b1',
  'url: guid=u1, name=Grok, parent_guid=b1, url=https://x.com/i/grok',
  'url: guid=u2, name=Claude, parent_guid=f1, url=https://claude.ai/',
);

is_deeply(\@got, \@exp, "export produces correct lines");

system($^X, $script, '--mode', 'export', '--profile', '0', '--output', "$dir/out2.b") == 0 or die "deterministic run failed";
my @got2 = sort map { chomp; $_ } do { local $/; open my $f, '<', "$dir/out2.b"; <$f> =~ /(.*)/gs };
is_deeply(\@got2, \@got, "export is deterministic");

ok(-s "$dir/out.b" > 200, "reasonable output size");
ok(grep(/root=bookmark_bar/, @got), "root tagged correctly");
