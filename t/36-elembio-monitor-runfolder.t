use strict;
use warnings;
use File::Copy;
use Test::More tests => 8;
use Test::Exception;
use Test::Warn;
use File::Temp qw/ tempdir /;
use File::Spec::Functions qw( catdir );
use File::Slurp;

use t::dbic_util;
use t::elembio_util qw( make_run_folder );
use Monitor::Elembio::Enum qw( 
  $CYCLES
  $DATE
  $FLOWCELL
  $FOLDER_NAME
  $INSTRUMENT_NAME
  $LANES
  $RUN_NAME
  $RUN_CYTOPROFILE
  $RUN_TYPE
  $RUN_STANDARD
  $RUN_STATUS_COMPLETE
  $RUN_STATUS_INPROGRESS
  $RUN_STATUS_TIME_PATTERN
  $RUN_STATUS_TYPE
  $SIDE
  $TIME_PATTERN
);
use_ok('Monitor::Elembio::RunFolder');

my $schema = t::dbic_util->new->test_schema();

subtest 'test run parameters loader' => sub {
  plan tests => 11;

  my $testdir = tempdir( CLEANUP => 1 );
  my $test_params = {
    $INSTRUMENT_NAME => q[AV244103],
    $FLOWCELL => q[1234567890],
    $RUN_NAME => q[NT1234567B],
    $SIDE => q[A],
    $DATE => q[2025-04-11T12:00:59.792171889Z],
    $CYCLES => { map {$_ => 0} ('I1','I2','R1','R2') },
    $LANES => [1,2],
    $FOLDER_NAME => q[20250411_AV244103_NT1234567B],
    $RUN_TYPE => $RUN_STANDARD,
    $RUN_STATUS_TYPE => $RUN_STATUS_INPROGRESS
  };
  my $runfolder_path = catdir($testdir, $test_params->{$INSTRUMENT_NAME}, $test_params->{$FOLDER_NAME});
  make_run_folder(
    $testdir,
    $test_params
  );

  my $test = Monitor::Elembio::RunFolder->new( runfolder_path      => $runfolder_path,
                                                npg_tracking_schema => $schema);
  isa_ok( $test, 'Monitor::Elembio::RunFolder' );
  is( $test->folder_name, $test_params->{$FOLDER_NAME}, 'run_folder value correct' );
  is( $test->flowcell_id, $test_params->{$FLOWCELL}, 'flowcell_id value correct' );
  isa_ok( $test->tracking_instrument(), 'npg_tracking::Schema::Result::Instrument',
          'Object returned by tracking_instrument method' );
  is( $test->tracking_instrument()->id_instrument, '100', 'instrument_id value correct' );
  is( $test->instrument_side, $test_params->{$SIDE}, 'side value correct' );
  is( $test->expected_cycle_count, 318, 'expected cycle value correct' );
  is( $test->actual_cycle_count, 0, 'actual cycle value correct' );
  is( $test->lane_count, 2, 'lanes number value correct' );
  is( $test->date_created->strftime($TIME_PATTERN), $test_params->{$DATE}, 'date_created value correct' );
  isa_ok( $test->tracking_run(), 'npg_tracking::Schema::Result::Run',
          'Object returned by tracking_run method' );
};

subtest 'test run parameters loader exceptions' => sub {
  plan tests => 5;

  my $testdir = tempdir( CLEANUP => 1 );
  my $test_params = {
    $INSTRUMENT_NAME => q[AV244103],
    $FLOWCELL => q[],
    $RUN_NAME => q[NT1234567B],
    $SIDE => q[],
    $DATE => q[],
    $CYCLES => { map {$_ => 0} ('I1','I2','R1','R2') },
    $LANES => [],
    $FOLDER_NAME => q[],
    $RUN_TYPE => $RUN_STANDARD,
    $RUN_STATUS_TYPE => $RUN_STATUS_INPROGRESS
  };
  my $runfolder_path = catdir($testdir, $test_params->{$INSTRUMENT_NAME}, $test_params->{$FOLDER_NAME});
  make_run_folder(
    $testdir,
    $test_params
  );

  my $test = Monitor::Elembio::RunFolder->new( runfolder_path      => $runfolder_path,
                                                npg_tracking_schema => $schema);
  throws_ok{ $test->folder_name }
    qr/Empty[ ]value[ ]in[ ]folder_name/msx,
    'folder name empty';
  throws_ok{ $test->flowcell_id }
    qr/Empty[ ]value[ ]in[ ]flowcell_id/msx,
    'flowcell ID empty';
  throws_ok { $test->instrument_side }
    qr/Run[ ]parameter[ ]Side:[ ]wrong[ ]format[ ]in[ ]RunParameters[.]json/msx,
    'wrong side value';
  ok( $test->date_created, 'missing date gives current date of RunParameters file' );

  my $testdir2 = tempdir( CLEANUP => 1 );
  $test_params->{$DATE} = '2025-04-16T12:00:59';
  my $runfolder_path2 = catdir($testdir2, $test_params->{$INSTRUMENT_NAME}, $test_params->{$FOLDER_NAME});
  make_run_folder(
    $testdir2,
    $test_params
  );
  my $test2 = Monitor::Elembio::RunFolder->new( runfolder_path      => $runfolder_path2,
                                                npg_tracking_schema => $schema);
  ok( $test2->date_created, 'wrong date format gives current date of RunParameters file' );
};

subtest 'test run parameters update on new run' => sub {
  plan tests => 18;

  my $testdir = tempdir( CLEANUP => 1 );
  my $test_params = {
    $INSTRUMENT_NAME => q[AV244103],
    $FLOWCELL => q[2345678901],
    $RUN_NAME => q[NT1234567C],
    $SIDE => q[A],
    $DATE => q[2025-04-11T12:00:59.792171889Z],
    $CYCLES => { map {$_ => 0} ('I1','I2','R1','R2') },
    $LANES => [1,2],
    $FOLDER_NAME => q[20250411_AV244103_NT1234567C],
    $RUN_TYPE => $RUN_STANDARD,
    $RUN_STATUS_TYPE => $RUN_STATUS_INPROGRESS
  };
  my $runfolder_path = catdir($testdir, $test_params->{$INSTRUMENT_NAME}, $test_params->{$FOLDER_NAME});
  make_run_folder(
    $testdir,
    $test_params
  );

  my $test = Monitor::Elembio::RunFolder->new( runfolder_path      => $runfolder_path,
                                                npg_tracking_schema => $schema);
  ok( ! $test->tracking_run()->current_run_status, 'current_run_status not set');
  ok( ! $test->tracking_run()->current_run_status_description, 'current_run_status_description undef');
  lives_ok {$test->process_run_parameters();} 'process_run_parameters succeeds';
  is( $test->tracking_run()->folder_name, $test_params->{$FOLDER_NAME}, 'folder_name of new tracking run' );
  is( $test->tracking_run()->flowcell_id, $test_params->{$FLOWCELL}, 'flowcell_id of new tracking run' );
  is( $test->tracking_run()->id_instrument, '100', 'id_instrument of new tracking run' );
  is( $test->tracking_run()->id_instrument_format, 19, 'id_instrument_format of new tracking run' );
  is( $test->tracking_run()->instrument_side, $test_params->{$SIDE}, 'instrument_side of new tracking run' );
  is( $test->tracking_run()->expected_cycle_count, 318, 'expected_cycle_count of new tracking run' );
  is( $test->tracking_run()->actual_cycle_count, 0, 'actual_cycle_count of new tracking run' );
  is( $test->tracking_run()->team, 'SR', 'team of new tracking run' );
  is( $test->tracking_run()->priority, 1, 'priority of new tracking run' );
  is( $test->tracking_run()->is_paired, 1, 'team of new tracking run' );
  is( $test->tracking_run()->folder_path_glob, catdir($testdir, $test_params->{$INSTRUMENT_NAME}), 'folder_path_glob of new tracking run' );
  ok( $test->tracking_run()->current_run_status, 'current_run_status set in new run');
  is( $test->tracking_run()->current_run_status_description, $RUN_STATUS_INPROGRESS, 'current_run_status in progress of new run');
  is( 
    $test->tracking_run()->current_run_status->date->strftime($RUN_STATUS_TIME_PATTERN), 
    $test->date_created->strftime($RUN_STATUS_TIME_PATTERN),
    'current_run_status date set on run creation in new run');
  is( $test->tracking_run()->run_lanes->count(), 2, 'correct lanes number of new tracking run');
};

subtest 'test update on existing run in progress' => sub {
  plan tests => 6;
  my $testdir = tempdir( CLEANUP => 1 );
  my $test_params = {
    $INSTRUMENT_NAME => q[AV244103],
    $FLOWCELL => q[1234567890],
    $RUN_NAME => q[NT1234567B],
    $SIDE => q[A],
    $DATE => q[2025-04-11T12:00:59.792171889Z],
    $CYCLES => {
      I1 => 100,
      I2 => 100,
      R1 => 0,
      R2 => 0,
    },
    $LANES => [1,2],
    $FOLDER_NAME => q[20250411_AV244103_NT1234567B],
    $RUN_TYPE => $RUN_STANDARD,
    $RUN_STATUS_TYPE => $RUN_STATUS_INPROGRESS
  };
  my $runfolder_path = catdir($testdir, $test_params->{$INSTRUMENT_NAME}, $test_params->{$FOLDER_NAME});
  make_run_folder(
    $testdir,
    $test_params
  );

  my $test = Monitor::Elembio::RunFolder->new( runfolder_path      => $runfolder_path,
                                                npg_tracking_schema => $schema);
  is( $test->tracking_run()->instrument_side, $test_params->{$SIDE}, 'instrument_side of existing tracking run' );
  ok( $test->tracking_run()->current_run_status, 'current_run_status set');
  is( $test->tracking_run()->current_run_status_description, $RUN_STATUS_INPROGRESS, 'current_run_status in progress of existing run');
  lives_ok {$test->process_run_parameters();} 'process_run_parameters no change';
  is( $test->tracking_run()->actual_cycle_count, 200, 'actual_cycle_count no change' );
  is( $test->tracking_run()->current_run_status_description, $RUN_STATUS_INPROGRESS, 'current_run_status no change');
};

subtest 'test update on existing run actual cycle counter' => sub {
  plan tests => 3;
  my $testdir = tempdir( CLEANUP => 1 );
  my $test_params = {
    $INSTRUMENT_NAME => q[AV244103],
    $FLOWCELL => q[1234567890],
    $RUN_NAME => q[NT1234567B],
    $SIDE => q[A],
    $DATE => q[2025-04-11T12:00:59.792171889Z],
    $CYCLES => {
      I1 => 100,
      I2 => 100,
      R1 => 8,
      R2 => 0,
      P1 => 1,
    },
    $LANES => [1,2],
    $FOLDER_NAME => q[20250411_AV244103_NT1234567B],
    $RUN_TYPE => $RUN_STANDARD,
    $RUN_STATUS_TYPE => $RUN_STATUS_INPROGRESS
  };
  my $runfolder_path = catdir($testdir, $test_params->{$INSTRUMENT_NAME}, $test_params->{$FOLDER_NAME});
  make_run_folder(
    $testdir,
    $test_params
  );

  my $test = Monitor::Elembio::RunFolder->new( runfolder_path      => $runfolder_path,
                                                npg_tracking_schema => $schema);
  is( $test->tracking_run()->actual_cycle_count, 200, 'actual_cycle_count init' );
  lives_ok {$test->process_run_parameters();} 'process_run_parameters success';
  is( $test->tracking_run()->actual_cycle_count, 208, 'actual_cycle_count progressed forward' );
};

subtest 'test on existing run in progress and completed on disk' => sub {
  plan tests => 10;
  my $testdir = tempdir( CLEANUP => 1 );
  my $test_params = {
    $INSTRUMENT_NAME => q[AV244103],
    $FLOWCELL => q[3456789012],
    $RUN_NAME => q[NT1234567A],
    $SIDE => q[A],
    $DATE => q[2025-05-13T12:00:59.792171889Z],
    $CYCLES => {
      I1 => 151,
      I2 => 151,
      R1 => 8,
      R2 => 8,
      P1 => 1,
    },
    $LANES => [1,2],
    $FOLDER_NAME => q[20250513_AV244103_NT1234567A],
    $RUN_TYPE => $RUN_STANDARD,
    $RUN_STATUS_TYPE => $RUN_STATUS_COMPLETE
  };
  my $runfolder_path = catdir($testdir, $test_params->{$INSTRUMENT_NAME}, $test_params->{$FOLDER_NAME});
  make_run_folder(
    $testdir,
    $test_params
  );

  my $test = Monitor::Elembio::RunFolder->new( runfolder_path      => $runfolder_path,
                                                npg_tracking_schema => $schema);
  is( $test->actual_cycle_count, 318, 'actual_cycle_count on max' );
  is( $test->tracking_run()->actual_cycle_count, 200, 'actual_cycle_count start in the middle' );
  ok( $test->tracking_run()->current_run_status, 'current_run_status set');
  is( $test->tracking_run()->current_run_status_description, $RUN_STATUS_INPROGRESS, 'current_run_status in progress');
  is( 
    $test->tracking_run()->current_run_status->date->strftime($RUN_STATUS_TIME_PATTERN), 
    $test->date_created->strftime($RUN_STATUS_TIME_PATTERN),
    'current_run_status date set on run creation');
  lives_ok {$test->process_run_parameters();} 'process_run_parameters success';
  is( $test->tracking_run()->run_statuses()->count, 2, 'correct number of statuses');
  is( $test->tracking_run()->actual_cycle_count, 318, 'actual_cycle_count set on max in db' );
  is( $test->tracking_run()->current_run_status_description, $RUN_STATUS_COMPLETE, 'current_run_status on complete');
  ok(
    DateTime->compare($test->date_created, $test->tracking_run()->current_run_status->date) == -1,
    'run complete date more recent than run in progress');
};

subtest 'test on not existing run but already completed on disk' => sub {
  plan tests => 11;
  my $testdir = tempdir( CLEANUP => 1 );
  my $test_params = {
    $INSTRUMENT_NAME => q[AV244103],
    $FLOWCELL => q[4567890123],
    $RUN_NAME => q[NT1234567D],
    $SIDE => q[A],
    $DATE => q[2025-05-13T12:00:59.792171889Z],
    $CYCLES => {
      I1 => 151,
      I2 => 151,
      R1 => 8,
      R2 => 8,
      P1 => 1,
    },
    $LANES => [1,2],
    $FOLDER_NAME => q[20250513_AV244103_NT1234567D],
    $RUN_TYPE => $RUN_STANDARD,
    $RUN_STATUS_TYPE => $RUN_STATUS_COMPLETE
  };
  my $runfolder_path = catdir($testdir, $test_params->{$INSTRUMENT_NAME}, $test_params->{$FOLDER_NAME});
  make_run_folder(
    $testdir,
    $test_params
  );

  my $test = Monitor::Elembio::RunFolder->new( runfolder_path      => $runfolder_path,
                                                npg_tracking_schema => $schema);
  is( $test->actual_cycle_count, 318, 'actual_cycle_count on max' );
  is( $test->tracking_run()->actual_cycle_count, undef, 'actual_cycle_count undef on db' );
  ok( ! $test->tracking_run()->current_run_status, 'no current_run_status set');
  lives_ok {$test->process_run_parameters();} 'process_run_parameters success';
  is( $test->tracking_run()->run_statuses()->count, 2, 'correct number of statuses');
  is( $test->tracking_run()->actual_cycle_count, 318, 'actual_cycle_count set on max in db' );
  ok( $test->tracking_run()->current_run_status, 'current_run_status set after update');
  is( $test->tracking_run()->current_run_status_description, $RUN_STATUS_COMPLETE, 'current_run_status on complete');
  my @run_statuses = sort {
    DateTime->compare($a->date, $b->date)
  } $test->tracking_run()->run_statuses()->all();
  is( $run_statuses[0]->description, $RUN_STATUS_INPROGRESS, 'first run status is run in progress'); 
  is( $run_statuses[1]->description, $RUN_STATUS_COMPLETE, 'second run status is run complete'); 
  ok(
    DateTime->compare($test->date_created, $test->tracking_run()->current_run_status->date) == -1,
    'run complete date more recent than run in progress');
};

1;
