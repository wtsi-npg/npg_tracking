use strict;
use warnings;
use Test::More tests => 13;
use List::MoreUtils qw/uniq/;
use t::util;

use_ok('npg::model::search');

my $util = t::util->new({fixtures => 1,});

{
  my $search = npg::model::search->new({util => $util,});

  my $query = 'Lack of clusters';
  $search->query($query);
  my $results = $search->results();
  is((scalar @{$results}), 2, 'run and run-lane annotations');
  is($results->[0]->[0], 'run', 'run annotation first');
  is($results->[1]->[0], 'run_lane', 'run-lane annotation second');
  my @annotations = uniq map { $_->[3] } @{$results}; 
  ok((@annotations == 1) && ($annotations[0] eq "${query} - run cancelled"),
    'correct annotations are retrieved');

  $query = 'Training flow';
  $search->query($query);
  $results = $search->results();
  is((scalar @{$results}), 7, 'run and run-lane annotations');
  my $n = grep { $_->[0] eq 'run' } @{$results};
  is($n, 3, 'three run annotation');
  $n = grep { $_->[0] eq 'run_lane' } @{$results};
  is($n, 4, 'four run-lane annotation');
  @annotations = uniq map { $_->[3] } @{$results};
  ok((@annotations == 1) && ($annotations[0] eq 'Training Flowcell'),
    'correct annotations are retrieved');
}

{
  my $search = npg::model::search->new({
          util => $util,
               });

  $search->query('networked');
  my $results = $search->results();
  is((scalar @{$results}), 6, 'exact instrument annotation');
}

{
  my $search = npg::model::search->new({
          util => $util,
               });

  $search->query('1000Genomes-A2-TriosPilot');
  my $results = $search->results();
  is((scalar @{$results}), 2, '2 exact projects');
}

{
  my $search = npg::model::search->new({
          util => $util,
               });

  $search->query('NA12878-WG');
  my $results = $search->results();
  is((scalar @{$results}), 2, '2 exact library');
}

{
  my $search = npg::model::search->new({
          util => $util,
               });

  $search->query('939');
  my $results = $search->results();
  is((scalar @{$results}), 1, 'exact batch id');
}

1;
