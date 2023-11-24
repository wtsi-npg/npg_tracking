use strict;
use warnings;
use Test::More tests => 6;
use Test::Deep;
use Test::Exception;
use DateTime;
use DateTime::Duration;

use t::dbic_util;

use_ok('npg_tracking::Schema::Result::Instrument');

my $schema = t::dbic_util->new->test_schema();

subtest 'basic instrument tests - create and retrieve' => sub {
  plan tests => 15;

  my $test = $schema->resultset('Instrument')->find({ id_instrument => 6 });
  isa_ok( $test, 'npg_tracking::Schema::Result::Instrument', 'Correct class' );
  is( $test->current_instrument_status(), 'wash required',
    'new instrument status returned' );

  $test = $schema->resultset('Instrument')->find({id_instrument => 69});
  is( $test->name, 'NVX1', 'correct instrument name');
  is( $test->instrument_format->model, 'NovaSeqX', 'is NovaSeqX instrument'); 
  is( $test->lab, 'Ogilvie','correct lab location');
  ok( $test->does_sequencing(), 'is a sequencing instrument');

  my $name = 'new name';
  lives_ok { $test = $schema->resultset('Instrument')->create({
      id_instrument => 100,
      id_instrument_format => 10,
      name => $name,
      external_name => 'external',
      serial => '12345',
      iscurrent => 1,       
    })
  } 'no error creating a new HiSeq instrument';
  is( $test->name, $name, 'new instrument name is correct');
  is( $test->instrument_format->model, 'HiSeq', 'is HiSeq instrument');
  is( $test->current_instrument_status,
    'wash required', 'initial instrument status is set');

  throws_ok { $schema->resultset('Instrument')->create({
      id_instrument => 101,
      id_instrument_format => 20,
      name => $name . '1',
      external_name => 'external',
      serial => '12345',
      iscurrent => 1,       
    })
  } qr/call method \"model\" on an undefined value/,
  'error creating a new instrument with unknown format';

  $name = $name . q[2];
  lives_ok { $test = $schema->resultset('Instrument')->create({
      id_instrument => 102,
      id_instrument_format => 7,
      name => $name,
      external_name => 'external',
      serial => '12345',
      iscurrent => 1,       
    })
  } 'no error creating a new cbot instrument';
  is( $test->name, $name, 'new instrument name is correct');
  is( $test->instrument_format->model, 'cBot', 'is cBot instrument');
  is( $test->current_instrument_status, undef, 'no initial instrument status');  
};

subtest 'instrument status updates' => sub {
  plan tests => 17;

  my $test_instrument_id = 6;

  my $test = $schema->resultset('Instrument')->find(
    { id_instrument => $test_instrument_id } );
  my $wash_interval = $test->instrument_format->days_between_washes;

  my $id = $schema->resultset('InstrumentStatusDict')
    ->find({description => 'wash performed',})->id_instrument_status_dict;
  $schema->resultset('InstrumentStatus')->create({
    id_instrument => $test_instrument_id,
    id_instrument_status_dict => $id,
    id_user => 1,
    iscurrent => 0,
    date => DateTime->now()
      ->subtract_duration(DateTime::Duration->new(days=>$wash_interval+4)),
  });

  throws_ok {
    $test->update_instrument_status('down', 'joe_engineer', 'instrument is down')
  } qr/Instrument status \'down\' is not current/,
    'error attempting to changed status to down (not current)';
  lives_ok {$test->update_instrument_status(
    'planned repair', 'joe_engineer', 'instrument is down')
  } 'status changed to planned repair';
  ok(!$test->set_status_wash_requied_if_needed(), 'wash not needed');
  is($test->current_instrument_status, 'planned repair', 'status has not changed');

  lives_ok { $test->update_instrument_status( 'planned repair', 'joe_loader' ) }
    'Set a status that is already current';
  my $instrument_status_rs = $schema->resultset('InstrumentStatus')->search({
    id_instrument => $test_instrument_id,
    iscurrent     => 1,
  });
  is( $instrument_status_rs->first->comment(), 'instrument is down',
    'original comment' );

  lives_ok {
    $test->update_instrument_status('request approval', 'pipeline', 'to approve')
  } 'Set a new status';
  my $instrument_status = $schema->resultset('InstrumentStatus')->find({
    id_instrument => $test_instrument_id,
      iscurrent     => 1,
  });
  is( $instrument_status->comment(),
    'automatic status update : to approve', 'pipeline comment' );
  is($test->current_instrument_status,  'request approval',
    'current instrument status');
  ok(!$test->set_status_wash_requied_if_needed(), 'wash not needed');

  $instrument_status_rs = $schema->resultset('InstrumentStatus')->search({
    id_instrument => $test_instrument_id,
    iscurrent     => 1,
  });
  is( $instrument_status_rs->count(), 1, 'Only one row is current' );

  lives_ok {$test->update_instrument_status('up', 'pipeline')}
    'Status set by automatic pipeline';

  $instrument_status_rs = $schema->resultset('InstrumentStatus')->search({
    id_instrument => $test_instrument_id,
    iscurrent     => 1,
  });
  is( $instrument_status_rs->first->comment(), 'automatic status update',
    'Comment reflects automatic status update without custom comment' );

  $instrument_status_rs = $schema->resultset('InstrumentStatus')->search({
    id_instrument => $test_instrument_id,
    iscurrent     => 0,
  });
  is( $instrument_status_rs->count(), 4, '4 non-current rows' );
  ok( $test->set_status_wash_requied_if_needed(),
    'wash needed, wash required status has been set');
  is( $test->current_instrument_status, 'wash required',
    'status changed to wash required');
  ok( !$test->set_status_wash_requied_if_needed(),
    'wash does not need to be set');
};

subtest 'automatic status updates' => sub {
  plan tests => 4;

  my $hs = $schema->resultset('Instrument')->create({
    id_instrument        => 103,
    id_instrument_format => 10,
    name                 => 'HS',
    external_name        => 'external',
    serial               => '12345',
    iscurrent            => 1,
  });
  is($hs->instrument_format->model, 'HiSeq', 'is HiSeq instrument');
  $hs->update_instrument_status('up', 'pipeline');
  $hs->autochange_status_if_needed('run complete', 'pipeline');
  is($hs->current_instrument_status, 'wash required',
    'HiSeq status automatically changes from up to wash_required');

  my $nv = $schema->resultset('Instrument')->create({
    id_instrument        => 104,
    id_instrument_format => 1,
    name                 => 'NV',
    external_name        => 'external',
    serial               => '12346',
    iscurrent            => 1,
  });
  is($nv->instrument_format->model, 'NovaSeq', 'is NovaSeq instrument');
  $nv->update_instrument_status('up', 'pipeline');
  $nv->autochange_status_if_needed('run complete', 'pipeline');
  is($nv->current_instrument_status, 'up',
    'NovaSeq status remains at up when automatically changed from up');
};

subtest 'instrument and associated runs' => sub {
  plan tests => 18;

  # HiSeq, two active runs
  my $test = $schema->resultset('Instrument')->find( { id_instrument => 67 } );
  my $active_rs = $test->current_runs();
  is( $active_rs->count(), 2, 'Find two active runs' );
  cmp_bag( [ $active_rs->get_column('id_run')->all() ], [ 5329, 5330 ],
    'Match the run ids' );

  # HiSeq, one active run
  $test = $schema->resultset('Instrument')->find( { id_instrument => 68 } );
  $active_rs = $test->current_runs();
  is( $active_rs->count(), 1, 'Find one active run' );
  cmp_bag( [ $active_rs->get_column('id_run')->all() ], [ 4329 ],
    'Match the run id' );

  # GAII, one active run
  $test = $schema->resultset('Instrument')->find( { id_instrument => 15 } );
  $active_rs = $test->current_runs();
  is( $active_rs->count(), 1, 'Find one active run' );
  ok( !$test->is_idle, 'instrument is not idle');
  cmp_bag( [ $active_rs->get_column('id_run')->all() ], [ 3 ],
    'Match the run id' );

  # up or idle instrument state, up and down for service statuses
  my $run = $schema->resultset('Run')->find({id_run => 3});
  is( $run->id_instrument, 15, 'the run is associated with the test instrument');
  $run->update_run_status('run complete', 'pipeline');
  ok( !$test->is_idle, 'instrument is not idle for run complete');
  $test->update_instrument_status('planned service', 'pipeline');
  $run->update_run_status('run mirrored', 'pipeline');
  ok( $test->is_idle, 'instrument is idle for run mirrored');
  is( $test->current_instrument_status, 'down for service',
    'status changed automatically to "down for service"');
  $test->update_instrument_status('request approval', 'pipeline');
  $test->update_instrument_status('up', 'pipeline');
  ok( $test->set_status_wash_requied_if_needed(), 'wash status has been set');
  is( $test->current_instrument_status, 'wash required',
    'status changed to wash required');

  # GAII, one run on hold
  $test = $schema->resultset('Instrument')->find( { id_instrument => 3 } );
  $active_rs = $test->current_runs();
  is( $active_rs->count(), 1, 'One current run' );
  ok( !$test->is_idle, 'instrument is not idle');

  $run = $schema->resultset('Run')->find({id_run => 1});
  is( $run->id_instrument, 3, 'the run is associated with the test instrument');
  $run->update_run_status('run cancelled', 'pipeline');
  is( $test->current_runs()->count(), 0, 'no current runs' );
  ok( $test->is_idle, 'instrument is idle');
};

subtest 'retrieve latest instrument modification revision' => sub {
  plan tests => 7;

  # No modifications are registered for this instrument.
  my $instr = $schema->resultset('Instrument')->search({name => 'HS1'})->next();
  is( $instr->latest_revision_for_modification('Dragen'), undef,
    'Dragen mod revision is not available');

  # One modification one version is registered for this instrument.
  $instr = $schema->resultset('Instrument')->search({name => 'NV2'})->next();
  is( $instr->latest_revision_for_modification('NVCS'), 'v1.7.5',
    'correct NVCS modification revision');
  is( $instr->latest_revision_for_modification('Dragen'), undef,
    'Dragen mod revision is not available');
  
  # A few versions of the same modification are registered for instruments.
  $instr = $schema->resultset('Instrument')->search({name => 'NV1'})->next();
  is( $instr->latest_revision_for_modification('NVCS'), 'v1.8.1',
    'correct NVCS modification revision');
  $instr = $schema->resultset('Instrument')->search({name => 'MS2'})->next();
  is( $instr->latest_revision_for_modification('MCS'), 'v3.1.0.13',
    'correct MCS modification revision');
  
  # A few versions of different modifications.
  $instr = $schema->resultset('Instrument')->search({name => 'NVX1'})->next();
  is( $instr->latest_revision_for_modification('Dragen'), 'v4.1.7',
    'correct Dragen modification revision');
  is( $instr->latest_revision_for_modification('NXCS'), 'v1.2.0',
    'correct NXCS modification revision');
};

1;
