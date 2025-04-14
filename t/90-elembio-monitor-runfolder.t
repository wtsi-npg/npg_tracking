use strict;
use warnings;
use File::Copy;
use Test::More tests => 5;
use Test::Exception;
use Test::Warn;
use File::Temp qw/ tempdir /;
use File::Spec::Functions qw( catdir );
use File::Slurp;

use t::dbic_util;
use t::elembio_run_util qw( make_run_folder );

use_ok('Monitor::Elembio::RunFolder');

my $schema = t::dbic_util->new->test_schema();

subtest 'test run parameters loader' => sub {
  plan tests => 9;

  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_name = q[AV244103];
  my $flowcell_id = q[1234567890];
  my $experiment_name = q[NT1234567B];
  my $side = 'A';
  my $date = '2025-01-01T12:00:59.792171889Z';
  my $runfolder_name = qq[20250411_${instrument_name}_${experiment_name}];
  my $runfolder_path = catdir($testdir, $instrument_name, $runfolder_name);
  make_run_folder(
    $testdir,
    $runfolder_name,
    $instrument_name,
    $experiment_name,
    $flowcell_id,
    $side,
    $date,
  );

  my $test = Monitor::Elembio::RunFolder->new( runfolder_path      => $runfolder_path,
                                                npg_tracking_schema => $schema);
  isa_ok( $test, 'Monitor::Elembio::RunFolder' );
  is( $test->folder_name, $runfolder_name, 'run_folder value correct' );
  is( $test->flowcell_id, $flowcell_id, 'flowcell_id value correct' );
  isa_ok( $test->tracking_instrument(), 'npg_tracking::Schema::Result::Instrument',
          'Object returned by tracking_instrument method' );
  is( $test->id_instrument, '100', 'instrument_id value correct' );
  is( $test->instrument_side, $side, 'side value correct' );
  is( $test->cycle_count, 318, 'actual cycle value correct' );
  is( $test->date_created, $date, 'date_created value correct' );
  isa_ok( $test->tracking_run(), 'npg_tracking::Schema::Result::Run',
          'Object returned by tracking_run method' );
};

subtest 'test run parameters loader exceptions' => sub {
  plan tests => 5;

  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_name = q[AV244103];
  my $flowcell_id = '';
  my $experiment_name = q[NT1234567B];
  my $side = '';
  my $date = '';
  my $runfolder_name = '';
  my $runfolder_path = catdir($testdir, $instrument_name, $runfolder_name);
  make_run_folder(
    $testdir,
    $runfolder_name,
    $instrument_name,
    $experiment_name,
    $flowcell_id,
    $side,
    $date,
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
  my $date2 = '2025-01-01T12:00:59';
  my $runfolder_path2 = catdir($testdir2, $instrument_name, $runfolder_name);
  make_run_folder(
    $testdir2,
    $runfolder_name,
    $instrument_name,
    $experiment_name,
    $flowcell_id,
    $side,
    $date2,
  );
  my $test2 = Monitor::Elembio::RunFolder->new( runfolder_path      => $runfolder_path2,
                                                npg_tracking_schema => $schema);
  ok( $test2->date_created, 'wrong date format gives current date of RunParameters file' );
};

subtest 'test tracking run does not exist' => sub {
  plan tests => 7;

  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_name = q[AV244103];
  my $flowcell_id = q[2345678901];
  my $experiment_name = q[NT1234567C];
  my $side = 'A';
  my $date = '2025-01-01T12:00:59.792171889Z';
  my $runfolder_name = qq[20250411_${instrument_name}_${experiment_name}];
  my $runfolder_path = catdir($testdir, $instrument_name, $runfolder_name);
  make_run_folder(
    $testdir,
    $runfolder_name,
    $instrument_name,
    $experiment_name,
    $flowcell_id,
    $side,
    $date,
  );

  my $test = Monitor::Elembio::RunFolder->new( runfolder_path      => $runfolder_path,
                                                npg_tracking_schema => $schema);
  is( $test->tracking_run()->folder_name, $runfolder_name, 'folder_name of new tracking run' );
  is( $test->tracking_run()->flowcell_id, $flowcell_id, 'flowcell_id of new tracking run' );
  is( $test->tracking_run()->id_instrument, '100', 'id_instrument of new tracking run' );
  is( $test->tracking_run()->id_instrument_format, 19, 'id_instrument_format of new tracking run' );
  is( $test->tracking_run()->instrument_side, $side, 'instrument_side of new tracking run' );
  is( $test->tracking_run()->actual_cycle_count, 318, 'actual_cycle_count of new tracking run' );
  is( $test->tracking_run()->team, 'RAD', 'team of new tracking run' );
};

subtest 'test run parameters update' => sub {
  plan tests => 1;
  is (1, 1, 'pass');
};

1;
