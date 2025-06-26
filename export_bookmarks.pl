#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use File::Slurp;
use Getopt::Long;

# Command-line argument parsing
my $profile;
my $output;
GetOptions(
    "profile=i" => \$profile,
    "output=s"  => \$output
) or die "Usage: $0 --profile N --output file.txt\n";

# Check for required arguments
die "Error: --profile and --output are required.\nUsage: $0 --profile N --output file.txt\n"
    unless defined $profile && defined $output;

# Construct the path to the Chromium bookmarks file
my $bookmarks_file = "$ENV{HOME}/.config/chromium/Profile $profile/Bookmarks";
die "Error: Bookmarks file not found at $bookmarks_file\n" unless -f $bookmarks_file;

# Read and parse the JSON file
my $json_text;
eval {
    $json_text = read_file($bookmarks_file);
};
die "Error: Failed to read bookmarks file: $@\n" if $@;

my $data;
eval {
    $data = decode_json($json_text);
};
die "Error: Invalid JSON in bookmarks file: $@\n" if $@;

# Check if 'roots' key exists
die "Error: Bookmarks file has no 'roots' key\n" unless exists $data->{roots};

# Array to store flattened bookmark lines
my @lines;

# Recursive subroutine to flatten the bookmark hierarchy
sub flatten_bookmarks {
    my ($node, $parent_info) = @_;

    # Ensure node is a hash reference with a 'type'
    return unless ref($node) eq 'HASH' && exists $node->{type} && exists $node->{guid};

    if ($node->{type} eq "folder") {
        my @attrs;
        # Top-level folder (root) or subfolder
        if ($parent_info =~ /^[a-z_]+$/) {  # Root keys like "bookmark_bar"
            push @attrs, "root=$parent_info";
        } else {
            push @attrs, "parent_guid=$parent_info";
        }
        # Include all attributes except 'type', 'guid', 'children'
        push @attrs, map { "$_=$node->{$_}" }
            grep { $_ ne 'type' && $_ ne 'guid' && $_ ne 'children' }
            keys %$node;
        my $line = "folder: guid=$node->{guid}, " . join(", ", @attrs);
        push @lines, $line;

        # Recurse into children if they exist
        if (exists $node->{children} && ref($node->{children}) eq 'ARRAY') {
            for my $child (@{$node->{children}}) {
                flatten_bookmarks($child, $node->{guid});
            }
        }
    } elsif ($node->{type} eq "url") {
        my @attrs = ("parent_guid=$parent_info");
        # Include all attributes except 'type', 'guid'
        push @attrs, map { "$_=$node->{$_}" }
            grep { $_ ne 'type' && $_ ne 'guid' }
            keys %$node;
        my $line = "url: guid=$node->{guid}, " . join(", ", @attrs);
        push @lines, $line;
    }
}

# Process each root folder
for my $root (qw(bookmark_bar other synced)) {
    if (exists $data->{roots}{$root}) {
        flatten_bookmarks($data->{roots}{$root}, $root);
    }
}

# Sort lines for consistency
@lines = sort @lines;

# Write to output file
eval {
    write_file($output, { atomic => 1 }, join("\n", @lines) . "\n");
};
die "Error: Failed to write to output file $output: $@\n" if $@;

print "Bookmarks exported to $output\n";