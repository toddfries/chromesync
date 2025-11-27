#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 4;
use FindBin qw($Bin);
my $script = "$Bin/../export_bookmarks.pl";

# Use embedded minimal valid Chrome JSON — no real files touched
my $fake_json = <<'JSON';
{
  "checksum": "abc123",
  "roots": {
    "bookmark_bar": {
      "type": "folder", "guid": "00000000-0000-0000-0000-000000000001",
      "name": "Bookmarks bar", "children": [
        { "type": "url", "guid": "11111111-1111-1111-1111-111111111111",
          "name": "Grok", "url": "https://x.com/i/grok" },
        { "type": "folder", "guid": "22222222-2222-2222-2222-222222222222",
          "name": "AI", "children": [
            { "type": "url", "guid": "33333333-3333-3333-3333-333333333333",
              "name": "Claude", "url": "https://claude.ai/" }
          ]
        }
      ]
    },
    "other": { "type": "folder", "guid": "00000000-0000-0000-0000-000000000002", "name": "Other bookmarks", "children": [] },
    "synced": { "type": "folder", "guid": "00000000-0000-0000-0000-000000000003", "name": "Mobile bookmarks", "children": [] }
  },
  "version": 1
}
JSON

use File::Temp qw(tempfile tempdir);
my $dir = tempdir(CLEANUP => 1);
open my $fh, '>', "$dir/Bookmarks" or die "can't write fake Bookmarks: $!";
print $fh $fake_json;
close $fh;

# Override home so it finds our fake profile
$ENV{HOME} = $dir;
$ENV{PATH} = "/usr/bin:/bin:/usr/local/bin";  # safety

system($^X, $script, '--profile', '0', '--output', "$dir/out.b") == 0
    or die "export failed";

my @lines = do { open my $f, '<', "$dir/out.b"; <$f> };
chomp @lines;
@lines = sort @lines;

my @expected = sort(
    'folder: guid=00000000-0000-0000-0000-000000000001, name=Bookmarks bar, root=bookmark_bar',
    'folder: guid=22222222-2222-2222-2222-222222222222, name=AI, parent_guid=00000000-0000-0000-0000-000000000001',
    'url: guid=11111111-1111-1111-1111-111111111111, name=Grok, parent_guid=00000000-0000-0000-0000-000000000001, url=https://x.com/i/grok',
    'url: guid=33333333-3333-3333-3333-333333333333, name=Claude, parent_guid=22222222-2222-2222-2222-222222222222, url=https://claude.ai/',
);

is_deeply(\@lines, \@expected, "export produces correct known output");

# Deterministic?
system($^X, $script, '--profile', '0', '--output', "$dir/out2.b") == 0 or die;
my @lines2 = do { open my $f, '<', "$dir/out2.b"; <$f> };
chomp @lines2;
is(join("\n", @lines2), join("\n", @lines), "export is deterministic");

ok(-s "$dir/out.b" > 200, "output has reasonable size");
ok(grep(/root=bookmark_bar/, @lines), "root folder correctly tagged");