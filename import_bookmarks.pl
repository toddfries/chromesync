#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use File::Slurp;
use Getopt::Long;

# Command-line argument parsing
my $profile;
my $input;
my $output;
GetOptions(
    "profile=i" => \$profile,
    "input=s"   => \$input,
    "output=s"  => \$output
) or die "Usage: $0 --profile N --input file.txt --output file.json\n";

# Check for required arguments
die "Error: --profile, --input, and --output are required.\nUsage: $0 --profile N --input file.txt --output file.json\n"
    unless defined $profile && defined $input && defined $output;

# Read the input text file
die "Error: Input file not found at $input\n" unless -f $input;
my @lines;
eval {
    @lines = read_file($input, chomp => 1);
};
die "Error: Failed to read input file $input: $@\n" if $@;

# Hash to store nodes by GUID
my %nodes_by_guid;

# Parse each line
for my $line (@lines) {
    next unless $line =~ /\S/;  # Skip empty lines
    my ($type, $attrs_str) = split /: /, $line, 2;
    unless (defined $type && defined $attrs_str) {
        warn "Warning: Skipping malformed line: $line\n";
        next;
    }
    unless ($type eq "folder" || $type eq "url") {
        warn "Warning: Unknown type in line: $line\n";
        next;
    }

    my @attrs = split /, /, $attrs_str;
    my %attributes;
    my $has_guid = 0;
    for my $attr (@attrs) {
        my ($key, $value) = split /=/, $attr, 2;
        unless (defined $key && defined $value) {
            warn "Warning: Invalid attribute in line: $line\n";
            next;
        }
        $attributes{$key} = $value;
        $has_guid = 1 if $key eq "guid";
    }

    unless ($has_guid) {
        warn "Warning: Skipping line with no guid: $line\n";
        next;
    }

    my $node;
    if ($type eq "folder") {
        $node = { type => "folder", children => [], %attributes };
    } elsif ($type eq "url") {
        $node = { type => "url", %attributes };
    }
    $nodes_by_guid{$node->{guid}} = $node;
}

# Check if we have any nodes
die "Error: No valid bookmark entries found in $input\n" unless %nodes_by_guid;

# Build the tree
my $tree = { roots => {} };
for my $guid (keys %nodes_by_guid) {
    my $node = $nodes_by_guid{$guid};
    if (exists $node->{root}) {
        my $root = delete $node->{root};
        $tree->{roots}{$root} = $node;
    }
    if (exists $node->{parent_guid}) {
        my $parent_guid = $node->{parent_guid};
        if (exists $nodes_by_guid{$parent_guid}) {
            push @{$nodes_by_guid{$parent_guid}{children}}, $node;
            delete $node->{parent_guid};
        } else {
            warn "Warning: Parent GUID $parent_guid not found for node $guid\n";
        }
    }
}

# Check if roots were populated
warn "Warning: No top-level roots found; output may be incomplete\n"
    unless keys %{$tree->{roots}};

# Encode to JSON and write to output file
my $json_text;
eval {
    $json_text = encode_json($tree);
};
die "Error: Failed to encode JSON: $@\n" if $@;

eval {
    write_file($output, { atomic => 1 }, $json_text);
};
die "Error: Failed to write to output file $output: $@\n" if $@;

print "Bookmarks imported to $output\n";