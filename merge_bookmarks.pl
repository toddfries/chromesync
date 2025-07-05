#!/usr/bin/perl
use strict;
use warnings;
use File::Slurp;
use Getopt::Long;
use Term::ReadLine;

# Command-line arguments
my $upstream_file;
my $local_file;
my $output_file;
GetOptions(
    "upstream=s" => \$upstream_file,
    "local=s"    => \$local_file,
    "output=s"   => \$output_file
) or die "Usage: $0 --upstream upstream_ttf.b --local local_ttf.b --output merged_ttf.b\n";

die "Error: --upstream, --local, and --output required.\n"
    unless defined $upstream_file && defined $local_file && defined $output_file;

# Read input files
die "Error: $upstream_file not found\n" unless -f $upstream_file;
die "Error: $local_file not found\n" unless -f $local_file;
my @upstream_lines = read_file($upstream_file, chomp => 1) or die "Error reading $upstream_file: $!\n";
my @local_lines = read_file($local_file, chomp => 1) or die "Error reading $local_file: $!\n";

# Initialize Term::ReadLine for interactive prompts
my $term = Term::ReadLine->new('Bookmark Merger');
my $prompt = "Choice: ";

# Parse a ttf.b file into a hash of nodes by guid
sub parse_bookmarks {
    my ($lines) = @_;
    my %nodes;
    for my $line (@$lines) {
        next unless $line =~ /\S/;
        my ($type, $attrs_str) = split /: /, $line, 2;
        next unless defined $type && defined $attrs_str && ($type eq "folder" || $type eq "url");

        my %attrs;
        for my $attr (split /, /, $attrs_str) {
            my ($key, $value) = split /=/, $attr, 2;
            next unless defined $key && defined $value;
            $attrs{$key} = $value;
        }
        next unless exists $attrs{guid};

        $nodes{$attrs{guid}} = {
            type => $type,
            line => $line,
            attrs => \%attrs
        };
    }
    return \%nodes;
}

# Parse both files
my $upstream_nodes = parse_bookmarks(\@upstream_lines);
my $local_nodes = parse_bookmarks(\@local_lines);

# Get all unique GUIDs
my %all_guids;
$all_guids{$_} = 1 for (keys %$upstream_nodes, keys %$local_nodes);
my @all_guids = sort keys %all_guids;

# Merged nodes
my @merged_lines;

# Helper to get parent description
sub get_parent_desc {
    my ($node, $nodes) = @_;
    my $parent = $node->{attrs}{root} // $node->{attrs}{parent_guid};
    if ($parent && $parent =~ /^[a-z_]+$/) {
        return "root $parent";
    } elsif ($parent && exists $nodes->{$parent}) {
        return "parent '$nodes->{$parent}{attrs}{name}' (guid=$parent)";
    }
    return "unknown parent";
}

# Process each GUID
for my $guid (@all_guids) {
    my $upstream_node = $upstream_nodes->{$guid};
    my $local_node = $local_nodes->{$guid};

    if ($upstream_node && $local_node) {
        # Node exists in both
        my %upstream_attrs = %{$upstream_node->{attrs}};
        my %local_attrs = %{$local_node->{attrs}};

        # Check parent difference
        my $upstream_parent = $upstream_attrs{root} // $upstream_attrs{parent_guid};
        my $local_parent = $local_attrs{root} // $local_attrs{parent_guid};
        my $parent_conflict = ($upstream_parent // '') ne ($local_parent // '');

        # Check attribute differences (excluding parent, order, and date_last_used)
        my %attrs_diff;
        for my $key (sort keys %upstream_attrs) {
            next if $key eq 'guid' || $key eq 'root' || $key eq 'parent_guid' || $key eq 'order' || $key eq 'date_last_used';
            my $upstream_val = $upstream_attrs{$key} // '';
            my $local_val = $local_attrs{$key} // '';
            $attrs_diff{$key} = [$upstream_val, $local_val] if $upstream_val ne $local_val;
        }
        my $attrs_conflict = %attrs_diff;

        # Handle date_last_used separately
        my $chosen_date_last_used = $upstream_attrs{date_last_used} // '0';
        if (exists $local_attrs{date_last_used} && $local_attrs{date_last_used} > $chosen_date_last_used) {
            $chosen_date_last_used = $local_attrs{date_last_used};
        }

        if ($parent_conflict || $attrs_conflict) {
            print "\nConflict for $upstream_node->{type} (guid=$guid, name=$upstream_attrs{name}):\n";

            # Handle parent conflict
            my $chosen_parent;
            my $chosen_order;
            if ($parent_conflict) {
                print "Parent conflict:\n";
                print "  upstream: ", get_parent_desc($upstream_node, $upstream_nodes), "\n";
                print "  local: ", get_parent_desc($local_node, $local_nodes), "\n";
                print "Choose parent (1=upstream, 2=local): ";
                my $choice = $term->readline($prompt);
                if ($choice eq '2') {
                    $chosen_parent = $local_parent;
                    $chosen_order = $local_attrs{order};
                } else {
                    $chosen_parent = $upstream_parent;
                    $chosen_order = $upstream_attrs{order};
                }
            } else {
                $chosen_parent = $upstream_parent // $local_parent;
                $chosen_order = $upstream_attrs{order} // $local_attrs{order};
            }

            # Handle attribute conflicts
            my %merged_attrs = %upstream_attrs;
            if ($attrs_conflict) {
                print "Attribute conflicts:\n";
                for my $key (sort keys %attrs_diff) {
                    print "  $key:\n";
                    print "    upstream: $attrs_diff{$key}[0]\n";
                    print "    local: $attrs_diff{$key}[1]\n";
                    print "  Choose (1=upstream, 2=local): ";
                    my $choice = $term->readline($prompt);
                    $merged_attrs{$key} = $attrs_diff{$key}[$choice eq '2' ? 1 : 0];
                }
            }

            # Set date_last_used
            $merged_attrs{date_last_used} = $chosen_date_last_used;

            # Build merged line
            my @attrs;
            if ($chosen_parent && $chosen_parent =~ /^[a-z_]+$/) {
                push @attrs, "root=$chosen_parent";
            } elsif ($chosen_parent) {
                push @attrs, "parent_guid=$chosen_parent", "order=$chosen_order";
            }
            push @attrs, map { "$_=$merged_attrs{$_}" }
                sort
                grep { $_ ne 'guid' && $_ ne 'root' && $_ ne 'parent_guid' && $_ ne 'order' }
                keys %merged_attrs;
            my $line = "$upstream_node->{type}: guid=$guid, " . join(", ", @attrs);
            push @merged_lines, $line;
        } else {
            # No conflict, use upstream version with updated date_last_used
            my %merged_attrs = %upstream_attrs;
            $merged_attrs{date_last_used} = $chosen_date_last_used;
            my @attrs;
            if ($upstream_parent && $upstream_parent =~ /^[a-z_]+$/) {
                push @attrs, "root=$upstream_parent";
            } elsif ($upstream_parent) {
                push @attrs, "parent_guid=$upstream_parent", "order=$upstream_attrs{order}";
            }
            push @attrs, map { "$_=$merged_attrs{$_}" }
                sort
                grep { $_ ne 'guid' && $_ ne 'root' && $_ ne 'parent_guid' && $_ ne 'order' }
                keys %merged_attrs;
            my $line = "$upstream_node->{type}: guid=$guid, " . join(", ", @attrs);
            push @merged_lines, $line;
        }
    } elsif ($upstream_node) {
        # Only in upstream
        push @merged_lines, $upstream_node->{line};
    } elsif ($local_node) {
        # Only in local
        push @merged_lines, $local_node->{line};
    }
}

# Sort lines for consistency
@merged_lines = sort @merged_lines;

# Write output
write_file($output_file, { atomic => 1 }, join("\n", @merged_lines) . "\n")
    or die "Error writing $output_file: $!\n";
print "Merged bookmarks written to $output_file\n";
