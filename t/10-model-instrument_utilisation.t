use strict;
use warnings;
use Test::More tests => 38;
use Test::Exception;
use t::util;

use_ok('npg::model::instrument_utilisation');
my $util = t::util->new({ fixtures => 1 });

{
  my $model = npg::model::instrument_utilisation->new({ util => $util });
  isa_ok($model, 'npg::model::instrument_utilisation', '$model');
  my $all = $model->instrument_utilisations();
  isa_ok($all, 'ARRAY', '$model->instrument_utilisations()');
  my $total_number_of_all_object = scalar@{$all};
  ok($total_number_of_all_object, "Number of instrument_utilisations = $total_number_of_all_object");
}
{
  my $model = npg::model::instrument_utilisation->new({ util => $util, date => '2008-01-01' });
  isa_ok($model, 'npg::model::instrument_utilisation', '$model');
  is($model->id_instrument_utilisation(), 1, '$model->id_instrument_utilisation()');
  is($model->total_insts(), 10, '$model->total_insts()');
  is($model->perc_utilisation_total_insts(), '100.00', '$model->perc_utilisation_total_insts()');
  is($model->perc_uptime_total_insts(), '100.00', '$model->perc_uptime_total_insts()');
  is($model->official_insts(), 8, '$model->official_insts()');
  is($model->perc_utilisation_official_insts(), '100.00', '$model->perc_utilisation_official_insts()');
  is($model->perc_uptime_official_insts(), '100.00', '$model->perc_uptime_official_insts()');
  is($model->prod_insts(), 7, '$model->prod_insts()');
  is($model->perc_utilisation_prod_insts(), '100.00', '$model->perc_utilisation_prod_insts()');
  is($model->perc_uptime_prod_insts(), '100.00', '$model->perc_uptime_prod_insts()');
}
{
  my $model = npg::model::instrument_utilisation->new({ util => $util, id_instrument_utilisation => 1 });
  isa_ok($model, 'npg::model::instrument_utilisation', '$model');
  is($model->date(), '2008-01-01', '$model->date()');
  is($model->total_insts(), 10, '$model->total_insts()');
  is($model->perc_utilisation_total_insts(), '100.00', '$model->perc_utilisation_total_insts()');
  is($model->perc_uptime_total_insts(), '100.00', '$model->perc_uptime_total_insts()');
  is($model->official_insts(), 8, '$model->official_insts()');
  is($model->perc_utilisation_official_insts(), '100.00', '$model->perc_utilisation_official_insts()');
  is($model->perc_uptime_official_insts(), '100.00', '$model->perc_uptime_official_insts()');
  is($model->prod_insts(), 7, '$model->prod_insts()');
  is($model->perc_utilisation_prod_insts(), '100.00', '$model->perc_utilisation_prod_insts()');
  is($model->perc_uptime_prod_insts(), '100.00', '$model->perc_uptime_prod_insts()');
}
{
  my $model = npg::model::instrument_utilisation->new({ util => $util });
  my $data;
  lives_ok { $data = $model->table_data_total_insts(); }
    'no croak on obtaining $model->graph_data_total_insts()';
  my $total_insts_30_days = [
    [qw(2008-01-01 10 100.00 100.00)],
    [qw(2008-01-02 10 100.00 100.00)],
    [qw(2008-01-03 10 100.00 100.00)],
    [qw(2008-01-04 10 100.00 100.00)],
    [qw(2008-01-05 10 100.00 100.00)],
  ];
  is_deeply($data, $total_insts_30_days, '$model->graph_data_total_insts()');
  lives_ok { $data = $model->table_data_official_insts(); }
    'no croak on obtaining $model->graph_data_official_insts()';
  my $official_insts_30_days = [
    [qw(2008-01-01 8 100.00 100.00)],
    [qw(2008-01-02 9 100.00 100.00)],
    [qw(2008-01-03 9 90.00 100.00)],
    [qw(2008-01-04 9 87.53 112.00)],
    [qw(2008-01-05 8 100.00 100.00)],
  ];
  is_deeply($data, $official_insts_30_days, '$model->graph_data_official_insts()');
  lives_ok { $data = $model->table_data_prod_insts(); }
    'no croak on obtaining $model->graph_data_prod_insts()';
  $total_insts_30_days = [
    [qw(2008-01-01 7 100.00 100.00)],
    [qw(2008-01-02 8 100.00 100.00)],
    [qw(2008-01-03 8 100.00 100.00)],
    [qw(2008-01-04 8 100.00 100.00)],
    [qw(2008-01-05 7 100.00 100.00)],
  ];
  is_deeply($data, $total_insts_30_days, '$model->graph_data_prod_insts()');

  throws_ok { $data = $model->last_x_days(); } qr/no\ instrument\ grouping\ provided/,
    'croaked last_x_days method call as no string provided';
  throws_ok { $data = $model->last_x_days( { insts => 'iwantsomeinsts', } ); }
    qr/Unknown\ column\ 'iwantsomeinsts'\ in\ 'field\ list'/,
    'croaked last_x_days method call as string does not match a column header';

  eval { $data = $model->graph_data( 'utilisation', q{}, q{HK} ); };
  my $test_deeply = [
    [qw(2008-01-01 100.00 100.00 100.00)],
    [qw(2008-01-02 100.00 100.00 100.00)],
    [qw(2008-01-03 100.00 90.00 100.00)],
    [qw(2008-01-04 100.00 87.53 100.00)],
    [qw(2008-01-05 100.00 100.00 100.00)],
  ];
  is_deeply($data, $test_deeply, 'utilisation data is correct');

  lives_ok  { $data = $model->graph_data( 'utilisation_uptime', q{}, q{HK} ); } 
    q{no croak with $model->graph_data('utilisation_uptime')};
  $test_deeply = [
    [qw(2008-01-01 100.00 100.00 100.00 )],
    [qw(2008-01-02 100.00 100.00 100.00 )],
    [qw(2008-01-03 100.00 90.00 100.00 )],
    [qw(2008-01-04 100.00 78.15 100.00 )],
    [qw(2008-01-05 100.00 100.00 100.00 )],
  ];
  is_deeply($data, $test_deeply, 'utilisation_uptime data is correct');
}
{
  my $model = npg::model::instrument_utilisation->new({
    util => $util,
    date => '2009-02-03',
    total_insts => 8,
    official_insts => 7,
    prod_insts => 6,
    perc_utilisation_total_insts => '0.00',
    perc_uptime_total_insts => '0.00',
    perc_utilisation_official_insts => '0.00',
    perc_uptime_official_insts => '0.00',
    perc_utilisation_prod_insts => '0.00',
    perc_uptime_prod_insts => '0.00',
    id_instrument_format => 10,
  });
  lives_ok { $model->create(); } 'no croak on create';
}

1;