use strict;
use warnings;
use Test::More tests => 6;
use t::util;

use_ok('npg::model::search');

my $util = t::util->new({
       fixtures => 1,
      });

{
  my $search = npg::model::search->new({
          util => $util,
               });

  $search->query('Lack of clusters');
  my $results = $search->results();
  is((scalar @{$results}), 1, 'exact run annotation');
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
