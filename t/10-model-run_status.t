use strict;
use warnings;
use Test::More tests => 15;
use Test::Exception;

use npg::model::run;
use t::util;

use_ok('npg::model::run_status');

my $util = t::util->new({ fixtures  => 1,});

{
  my $rs = npg::model::run_status->new({
          util => $util,
               });
  isa_ok($rs, 'npg::model::run_status');
  my $expected_data = [
    [ '9948', '2010-01-01 10:10:30', 'run complete',      1 ],
    [ '9949', '2010-01-01 10:10:33', 'run complete',      1 ],
    [ '9950', '2010-01-01 10:10:34', 'run complete',      1 ],
    [ '9951', '2010-01-01 10:10:34', 'run complete',      1 ],
    [ '1',    '2007-06-05 12:22:32', 'analysis complete', 1 ],
    [ '95',   '2007-06-05 12:22:32', 'analysis complete', 4 ],
    [ '5',    '2007-06-05 12:32:28', 'run mirrored',      1 ],
    [ '11',   '2007-06-05 12:31:44', 'run mirrored',      1 ],
    [ '12',   '2007-06-05 12:32:27', 'run mirrored',      1 ],
  ];

  is_deeply( $rs->_runs_at_requested_statuses(), $expected_data, q{correct data from _runs_at_requested_statuses obtained} );

  my $datetime = $rs->_datetime_now();
  is( $datetime, $rs->_datetime_now(), q{_datetime_now is cached correctly} );

  $datetime->set_day(28);
  $datetime->set_month(2);
  $datetime->set_year(2011);

  $expected_data = {
    'analysis complete' => [ { 'days' => 1364, 'id_run' => '1',  priority => 1 },
                             { 'days' => 1364, 'id_run' => '95', priority => 4 }, ],
    'run complete' => [ { 'days' => 423,  'id_run' => '9948', priority => 1 },
                        { 'days' => 423,  'id_run' => '9949', priority => 1 },
                        { 'days' => 423,  'id_run' => '9950', priority => 1 },
                        { 'days' => 423,  'id_run' => '9951', priority => 1 }, ],
    'run mirrored' => [ { 'days' => 1364, 'id_run' => '5',    priority => 1 },
                        { 'days' => 1364, 'id_run' => '11',   priority => 1 },
                        { 'days' => 1364, 'id_run' => '12',   priority => 1 }, ]
  };
  
  is_deeply( $rs->potentially_stuck_runs(), $expected_data, q{potentially_stuck_runs returns the expected data} );
}

{
  my $rs = npg::model::run_status->new({
          util => $util,
          id_run_status => 1,
               });
  isa_ok($rs->run(), 'npg::model::run');
  is($rs->run->id_run(), 1, 'id_run');

  isa_ok($rs->user(), 'npg::model::user');
  is($rs->user->id_user(), 1, 'id_user');

  isa_ok($rs->run_status_dict(), 'npg::model::run_status_dict');
  is($rs->run_status_dict->id_run_status_dict(), 1, 'id_user');
}

{
  my $model = npg::model::run_status->new({
             util               => $util,
             id_run             => 1,
             id_run_status_dict => 9,
             id_user            => 1,
            });
  $model->{run} = npg::model::run->new({id_run => 1, util => $util});
  lives_ok { $model->create();}
    'no croak on create for id_run_status_dict = 9 for id_run 1';
}

{
  my $model = npg::model::run_status->new({
             util               => $util,
             id_run             => 1,
             id_run_status_dict => 12,
             id_user            => 1,
            });
  $model->{run} = npg::model::run->new({id_run => 1, util => $util});
  lives_ok { $model->create(); }
    'no croak on create for id_run_status_dict = 12 for id_run 1';
}

{
  my $model = npg::model::run_status->new({
             util               => $util,
             id_run             => 1,
             id_run_status_dict => 4,
             id_user            => 1,
            });
  $model->{run} = npg::model::run->new({id_run => 1, util => $util});
  lives_ok { $model->create() }
    'no croak on create for id_run_status_dict = 4 for id_run 1';
}

{
  my $model = npg::model::run_status->new( {
    util => $util,
  } );
  my $potentially_stuck_runs = $model->potentially_stuck_runs();
  isa_ok( $potentially_stuck_runs, q{HASH}, q{$model->potentially_stuck_runs()} );
}

1;
