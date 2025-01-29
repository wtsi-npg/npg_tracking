use strict;
use warnings;
use t::util;
use Test::More tests => 8;

use_ok('npg::model::run_status_dict');

my $util = t::util->new({fixtures=>1});

{
  my $rsd = npg::model::run_status_dict->new({
                util        => $util,
                description => 'run pending',
               });
  is($rsd->id_run_status_dict(), 1, 'load by description');
}

{
  my $rsd = npg::model::run_status_dict->new({
                util        => $util,
                id_run_status_dict => 22,
               });
  is($rsd->description(), 'run stopped early', 'load by id');
}

{
  my $rsd = npg::model::run_status_dict->new({
                util        => $util,
                id_run_status_dict => 22,
               });
  my $rsds = $rsd->run_status_dicts();

  isa_ok($rsds, 'ARRAY');
  is((scalar @{$rsds}), 24, 'all run status dicts');
}

{
  my $rsd = npg::model::run_status_dict->new({
                util        => $util,
                id_run_status_dict => 22,
               });
  my $rsds = $rsd->run_status_dicts_sorted();
  my $rsds_length = scalar @{$rsds};

  isa_ok($rsds, 'ARRAY');
  is(($rsds_length), 21, 'all sorted run status dicts');

  my @sorted_run_status_dicts = sort {
    $a->{temporal_index} <=> $b->{temporal_index}
  } @{$rsds};

  is_deeply($rsds, \@sorted_run_status_dicts, 'Status list is in temporal index order');
}

1;
