# Simulate user always choosing local
my $input = "2\n2\n2\n";  # for each conflict

run3 ['./merge_bookmarks.pl', '--upstream', 'upstream, '--local',local, '--output',out],
     \$input, \undef, \undef;