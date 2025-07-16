#!/usr/bin/perl

# Copyright (c) 2025 Todd T. Fries <todd@fries.net>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use strict;
use warnings;
use JSON;
use File::Slurp;
use Getopt::Long;

# Command-line arguments
my $profile;
my $output;
GetOptions(
    "profile=i" => \$profile,
    "output=s"  => \$output
) or die "Usage: $0 --profile N --output file.txt\n";

die "Error: --profile and --output required.\nUsage: $0 --profile N --output file.txt\n"
    unless defined $profile && defined $output;

# Path to Chromium Bookmarks file
my $pname = "Profile $profile";
if ($profile == 0) {
	$pname = "Default";
}
my $bookmarks_file = $ENV{'HOME'}."/.config/chromium/${pname}/Bookmarks";
die "Error: Bookmarks file not found at $bookmarks_file\n" unless -f $bookmarks_file;

# Read and decode JSON
my $json_text = read_file($bookmarks_file) or die "Error: Failed to read $bookmarks_file: $!\n";
my $data = decode_json($json_text) or die "Error: Invalid JSON: $!\n";
die "Error: No 'roots' key in Bookmarks file\n" unless exists $data->{roots};

my @lines;


# Process roots
for my $root (qw(bookmark_bar other synced)) {
    flatten_bookmarks($data->{roots}{$root}, $root) if exists $data->{roots}{$root};
}

# Sort and write output
@lines = sort @lines;
write_file($output, { atomic => 1 }, join("\n", @lines) . "\n") or die "Error: Failed to write $output: $!\n";
print "Bookmarks exported to $output\n";

1;

sub flatten_bookmarks {
    my ($node, $parent_info) = @_;
    return unless ref($node) eq 'HASH' && exists $node->{type} && exists $node->{guid};

    if ($node->{type} eq "folder") {
        my @attrs;
        if ($parent_info =~ /^[a-z_]+$/) {  # Root keys
            push @attrs, "root=$parent_info";
        } else {
            push @attrs, "parent_guid=$parent_info";
        }
        push @attrs, map { "$_=$node->{$_}" }
            sort
            grep { $_ ne 'type' && $_ ne 'guid' && $_ ne 'children' && $_ ne 'date_modified' && $_ ne 'meta_info' }
            keys %$node;
        push @lines, "folder: guid=$node->{guid}, " . join(", ", @attrs);

        if (exists $node->{children} && ref($node->{children}) eq 'ARRAY') {
            for my $child (@{$node->{children}}) {
                flatten_bookmarks($child, $node->{guid});
            }
        }
    } elsif ($node->{type} eq "url") {
        my @attrs = ("parent_guid=$parent_info");
        push @attrs, map { "$_=$node->{$_}" }
            sort
            grep { $_ ne 'type' && $_ ne 'guid' && $_ ne 'date_modified' && $_ ne 'meta_info' }
            keys %$node;
        push @lines, "url: guid=$node->{guid}, " . join(", ", @attrs);
    }
}
