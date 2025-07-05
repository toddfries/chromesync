#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use File::Slurp;
use Getopt::Long;

# Command-line arguments
my $profile;
my $input;
my $output;
GetOptions(
    "profile=i" => \$profile,
    "input=s"   => \$input,
    "output=s"  => \$output
) or die "Usage: $0 --profile N --input file.txt --output file.json\n";

die "Error: --profile, --input, and --output required.\nUsage: $0 --profile N --input file.txt --output file.json\n"
    unless defined $profile && defined $input && defined $output;

# Read input text file
die "Error: Input file not found at $input\n" unless -f $input;
my @lines = read_file($input, chomp => 1) or die "Error: Failed to read $input: $!\n";

my %nodes_by_guid;

# Parse text file
for my $line (@lines) {
    next unless $line =~ /\S/;
    my ($type, $attrs_str) = split /: /, $line, 2;
    unless (defined $type && defined $attrs_str && ($type eq "folder" || $type eq "url")) {
        warn "Warning: Skipping invalid line: $line\n";
        next;
    }

    my %attributes;
    my $has_guid = 0;
    for my $attr (split /, /, $attrs_str) {
        my ($key, $value) = split /=/, $attr, 2;
        next unless defined $key && defined $value;
        $attributes{$key} = $value;
        $has_guid = 1 if $key eq "guid";
    }
    next unless $has_guid;

    my $node = $type eq "folder"
        ? { type => "folder", children => [], %attributes }
        : { type => "url", %attributes };
    $nodes_by_guid{$node->{guid}} = $node;
}

die "Error: No valid entries in $input\n" unless %nodes_by_guid;

# Build tree
my $tree = { roots => {} };
for my $guid (keys %nodes_by_guid) {
    my $node = $nodes_by_guid{$guid};
    if (exists $node->{root}) {
        $tree->{roots}{delete $node->{root}} = $node;
    }
    if (exists $node->{parent_guid}) {
        my $parent_guid = $node->{parent_guid};
        if (exists $nodes_by_guid{$parent_guid}) {
            push @{$nodes_by_guid{$parent_guid}{children}}, $node;
        } else {
            warn "Warning: Parent GUID $parent_guid not found for node $guid\n";
        }
    }
}

# Sort children by order and clean up attributes
for my $guid (keys %nodes_by_guid) {
    my $node = $nodes_by_guid{$guid};
    if ($node->{type} eq "folder" && exists $node->{children}) {
        $node->{children} = [ sort { $a->{order} <=> $b->{order} } @{$node->{children}} ];
    }
    delete $node->{order};
    delete $node->{parent_guid};
    # Add default meta_info to match original structure
    $node->{meta_info} = { power_bookmark_meta => "" };
    # Set default date_modified
    $node->{date_modified} = "0" unless exists $node->{date_modified};
}

warn "Warning: No top-level roots found; output may be incomplete\n"
    unless keys %{$tree->{roots}};

# Encode JSON with sorted keys and pretty-printing
my $json = JSON->new->canonical(1)->pretty;
my $json_text = $json->encode($tree) or die "Error: Failed to encode JSON: $!\n";

# Write output
write_file($output, { atomic => 1 }, $json_text) or die "Error: Failed to write $output: $!\n";
print "Bookmarks imported to $output\n";
