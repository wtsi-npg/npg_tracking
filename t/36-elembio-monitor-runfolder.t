use strict;
use warnings;
use File::Basename;
use File::Copy;
use File::Copy::Recursive qw( dircopy );
use Test::More tests => 8;
use Test::Exception;
use Test::Warn;
use File::Temp qw/ tempdir /;
use File::Spec::Functions qw( catdir );
use File::Slurp;

use t::dbic_util;
use t::elembio_util qw( update_run_folder );
use Monitor::Elembio::Enum qw(
  $CYCLES
  $RUN_TYPE
  $RUN_STANDARD
  $RUN_STATUS_COMPLETE
  $RUN_STATUS_INPROGRESS
  $RUN_STATUS_TIME_PATTERN
  $RUN_STATUS_TYPE
  $TIME_PATTERN
);
use_ok('Monitor::Elembio::RunFolder');

subtest 'test run parameters loader' => sub {
  plan tests => 11;

  my $schema = t::dbic_util->new->test_schema();
  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_folder = 'AV244103';
  my $flowcell_id = '1234567890';
  my $date = '2025-01-01T12:00:59.792171889Z';
  my $run_folder_name = '20250101_AV244103_NT1234567S';
  my $data_folder = catdir('t/data/elembio_staging', $instrument_folder, $run_folder_name);
  my $runfolder_path = catdir($testdir, $instrument_folder, $run_folder_name);
  dircopy($data_folder, $runfolder_path) or die "cannot copy test directory $!";

  my $test_params = {
    $RUN_TYPE => $RUN_STANDARD,
    $RUN_STATUS_TYPE => $RUN_STATUS_INPROGRESS
  };
  update_run_folder(
    $runfolder_path,
    $test_params
  );

  my $test = Monitor::Elembio::RunFolder->new( runfolder_path      => $runfolder_path,
                                                npg_tracking_schema => $schema);
  isa_ok( $test, 'Monitor::Elembio::RunFolder' );
  is( $test->folder_name, $run_folder_name, 'run_folder value correct' );
  is( $test->flowcell_id, $flowcell_id, 'flowcell_id value correct' );
  isa_ok( $test->tracking_instrument(), 'npg_tracking::Schema::Result::Instrument',
          'Object returned by tracking_instrument method' );
  is( $test->tracking_instrument()->id_instrument, '100', 'instrument_id value correct' );
  is( $test->instrument_side, 'A', 'side value correct' );
  is( $test->expected_cycle_count, 318, 'expected cycle value correct' );
  is( $test->actual_cycle_count, 0, 'actual cycle value correct' );
  is( $test->lane_count, 2, 'lanes number value correct' );
  is( $test->date_created->strftime($TIME_PATTERN), $date, 'date_created value correct' );
  isa_ok( $test->tracking_run(), 'npg_tracking::Schema::Result::Run',
          'Object returned by tracking_run method' );
};

subtest 'test run parameters loader exceptions' => sub {
  plan tests => 4;

  my $schema = t::dbic_util->new->test_schema();
  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_folder = 'AV244103';
  my $run_folder_name = '20250101_AV244103_NT1234567E';
  my $data_folder = catdir('t/data/elembio_staging', $instrument_folder, $run_folder_name);
  my $runfolder_path = catdir($testdir, $instrument_folder, $run_folder_name);
  dircopy($data_folder, $runfolder_path) or die "cannot copy test directory $!";

  my $test_params = {
    $RUN_TYPE => $RUN_STANDARD,
    $RUN_STATUS_TYPE => $RUN_STATUS_INPROGRESS
  };
  update_run_folder(
    $runfolder_path,
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
};

subtest 'test run parameters update on new run' => sub {
  plan tests => 18;

  my $schema = t::dbic_util->new->test_schema();
  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_folder = 'AV244103';
  my $flowcell_id = '1234567890';
  my $date = '2025-01-01T12:00:59.792171889Z';
  my $run_folder_name = '20250101_AV244103_NT1234567S';
  my $data_folder = catdir('t/data/elembio_staging', $instrument_folder, $run_folder_name);
  my $runfolder_path = catdir($testdir, $instrument_folder, $run_folder_name);
  dircopy($data_folder, $runfolder_path) or die "cannot copy test directory $!";

  my $test_params = {
    $RUN_TYPE => $RUN_STANDARD,
    $RUN_STATUS_TYPE => $RUN_STATUS_INPROGRESS
  };
  update_run_folder(
    $runfolder_path,
    $test_params
  );

  my $test = Monitor::Elembio::RunFolder->new( runfolder_path      => $runfolder_path,
                                                npg_tracking_schema => $schema);
  ok( ! $test->tracking_run()->current_run_status, 'current_run_status not set');
  ok( ! $test->tracking_run()->current_run_status_description, 'current_run_status_description undef');
  lives_ok {$test->process_run_parameters();} 'process_run_parameters succeeds';
  is( $test->tracking_run()->folder_name, $run_folder_name, 'folder_name of new tracking run' );
  is( $test->tracking_run()->flowcell_id, $flowcell_id, 'flowcell_id of new tracking run' );
  is( $test->tracking_run()->id_instrument, '100', 'id_instrument of new tracking run' );
  is( $test->tracking_run()->id_instrument_format, 19, 'id_instrument_format of new tracking run' );
  is( $test->tracking_run()->instrument_side, 'A', 'instrument_side of new tracking run' );
  is( $test->tracking_run()->expected_cycle_count, 318, 'expected_cycle_count of new tracking run' );
  is( $test->tracking_run()->actual_cycle_count, 0, 'actual_cycle_count of new tracking run' );
  is( $test->tracking_run()->team, 'SR', 'team of new tracking run' );
  is( $test->tracking_run()->priority, 1, 'priority of new tracking run' );
  is( $test->tracking_run()->is_paired, 1, 'team of new tracking run' );
  is( $test->tracking_run()->folder_path_glob, dirname($runfolder_path), 'folder_path_glob of new tracking run' );
  ok( $test->tracking_run()->current_run_status, 'current_run_status set in new run');
  is( $test->tracking_run()->current_run_status_description, $RUN_STATUS_INPROGRESS, 'current_run_status in progress of new run');
  is( 
    $test->tracking_run()->current_run_status->date->strftime($RUN_STATUS_TIME_PATTERN), 
    $test->date_created->strftime($RUN_STATUS_TIME_PATTERN),
    'current_run_status date set on run creation in new run');
  is( $test->tracking_run()->run_lanes->count(), 2, 'correct lanes number of new tracking run');
};

subtest 'test update progress on existing run' => sub {
  plan tests => 5;

  my $schema = t::dbic_util->new->test_schema();
  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_folder = 'AV244103';
  my $run_folder_name = '20250101_AV244103_NT1234568S';
  my $data_folder = catdir('t/data/elembio_staging', $instrument_folder, $run_folder_name);
  my $runfolder_path = catdir($testdir, $instrument_folder, $run_folder_name);
  dircopy($data_folder, $runfolder_path) or die "cannot copy test directory $!";

  my $test_params = {
    $CYCLES => {
      I1 => 100,
      I2 => 100,
      R1 => 0,
      R2 => 0,
    },
    $RUN_TYPE => $RUN_STANDARD,
    $RUN_STATUS_TYPE => $RUN_STATUS_INPROGRESS
  };
  update_run_folder(
    $runfolder_path,
    $test_params
  );

  my $test = Monitor::Elembio::RunFolder->new( runfolder_path      => $runfolder_path,
                                                npg_tracking_schema => $schema);
  ok( $test->tracking_run()->current_run_status, 'current_run_status set');
  is( $test->tracking_run()->current_run_status_description, $RUN_STATUS_INPROGRESS, 'current_run_status in progress of existing run');
  lives_ok {$test->process_run_parameters();} 'process_run_parameters no change';
  is( $test->tracking_run()->actual_cycle_count, 200, 'actual_cycle_count no change' );
  is( $test->tracking_run()->current_run_status_description, $RUN_STATUS_INPROGRESS, 'current_run_status no change');
};

subtest 'test update on existing run actual cycle counter' => sub {
  plan tests => 3;

  my $schema = t::dbic_util->new->test_schema();
  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_folder = 'AV244103';
  my $run_folder_name = '20250101_AV244103_NT1234568S';
  my $data_folder = catdir('t/data/elembio_staging', $instrument_folder, $run_folder_name);
  my $runfolder_path = catdir($testdir, $instrument_folder, $run_folder_name);
  dircopy($data_folder, $runfolder_path) or die "cannot copy test directory $!";

  my $test_params = {
    $CYCLES => {
      I1 => 100,
      I2 => 100,
      R1 => 8,
      R2 => 0,
      P1 => 1,
    },
    $RUN_TYPE => $RUN_STANDARD,
    $RUN_STATUS_TYPE => $RUN_STATUS_INPROGRESS
  };
  update_run_folder(
    $runfolder_path,
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

  my $schema = t::dbic_util->new->test_schema();
  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_folder = 'AV244103';
  my $run_folder_name = '20250101_AV244103_NT1234568S';
  my $data_folder = catdir('t/data/elembio_staging', $instrument_folder, $run_folder_name);
  my $runfolder_path = catdir($testdir, $instrument_folder, $run_folder_name);
  dircopy($data_folder, $runfolder_path) or die "cannot copy test directory $!";

  my $test_params = {
    $CYCLES => {
      I1 => 151,
      I2 => 151,
      R1 => 8,
      R2 => 8,
      P1 => 1,
    },
    $RUN_TYPE => $RUN_STANDARD,
    $RUN_STATUS_TYPE => $RUN_STATUS_COMPLETE
  };
  update_run_folder(
    $runfolder_path,
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

  my $schema = t::dbic_util->new->test_schema();
  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_folder = 'AV244103';
  my $flowcell_id = '1234567890';
  my $date = '2025-01-01T12:00:59.792171889Z';
  my $run_folder_name = '20250101_AV244103_NT1234567S';
  my $data_folder = catdir('t/data/elembio_staging', $instrument_folder, $run_folder_name);
  my $runfolder_path = catdir($testdir, $instrument_folder, $run_folder_name);
  dircopy($data_folder, $runfolder_path) or die "cannot copy test directory $!";

  my $test_params = {
    $CYCLES => {
      I1 => 151,
      I2 => 151,
      R1 => 8,
      R2 => 8,
      P1 => 1,
    },
    $RUN_TYPE => $RUN_STANDARD,
    $RUN_STATUS_TYPE => $RUN_STATUS_COMPLETE
  };
  update_run_folder(
    $runfolder_path,
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
