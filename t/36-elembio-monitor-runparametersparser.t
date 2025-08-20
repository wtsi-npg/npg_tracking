use strict;
use warnings;
use File::Copy::Recursive qw( dircopy );
use File::Spec::Functions qw( catdir );
use File::Temp qw( tempdir );
use Test::More tests => 4;
use Test::Exception;
use Test::Warn;

use_ok('Monitor::Elembio::RunParametersParser');

subtest 'test run parameters loader' => sub {
  plan tests => 16;

  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_folder = 'AV244103';
  my $run_name = '1234';
  my $run_folder_name = "20250417_${instrument_folder}_${run_name}";
  my $flowcell_id = '2441447657';
  my $date = '2025-04-17T13:57:00.861333784Z';
  my $data_folder = catdir('t/data/elembio_staging', $instrument_folder, $run_folder_name);
  my $runfolder_path = catdir($testdir, $instrument_folder, $run_folder_name);
  dircopy($data_folder, $runfolder_path) or die "cannot copy test directory $!";

  my $test = Monitor::Elembio::RunParametersParser->new(
    runfolder_path => $runfolder_path);
  isa_ok( $test, 'Monitor::Elembio::RunParametersParser' );
  is( $test->runparams_path, "$runfolder_path/RunParameters.json",
    'runparams_path is built correctly');
  is( $test->folder_name, $run_folder_name, 'run_folder value correct' );
  is( $test->flowcell_id, $flowcell_id, 'flowcell_id value correct' );
  is( $test->run_name, '1234', 'run name is correct');
  is( $test->batch_id, 1234, 'batch_id value correct' );
  is( $test->instrument_side, 'A', 'side value correct' );
  is( $test->expected_cycle_count, 210, 'expected cycle value correct' );
  is( $test->lane_count, 2, 'lanes number value correct' );
  is( $test->is_paired, 1, 'is_paired value correct' );
  is( $test->is_indexed, 1, 'is_indexed value correct' );
  is( $test->date_created->strftime('%Y-%m-%dT%H:%M:%S.%NZ'), $date,
    'date_created value correct' );
  is( $test->run_type, 'Sequencing', 'run_type value correct' );
  
  $test = Monitor::Elembio::RunParametersParser->new(
    runparams_path => "$runfolder_path/RunParameters.json");
  is( $test->runfolder_path, $runfolder_path,
    'run folder path is inferred correctly');
  is( $test->folder_name, $run_folder_name, 'run_folder value correct' );
  is( $test->flowcell_id, $flowcell_id, 'flowcell_id value correct' );
};

subtest 'test on cytoprofiling run' => sub {
  plan tests => 7;

  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_folder = 'AV244103';
  my $run_name = '2345';
  my $run_folder_name = "20250415_${instrument_folder}_${run_name}";
  my $data_folder = catdir('t/data/elembio_staging', $instrument_folder, $run_folder_name);
  my $runfolder_path = catdir($testdir, $instrument_folder, $run_folder_name);
  dircopy($data_folder, $runfolder_path) or die "cannot copy test directory $!";

  my $test = Monitor::Elembio::RunParametersParser->new(
    runfolder_path => $runfolder_path);
  isa_ok( $test, 'Monitor::Elembio::RunParametersParser' );
  is( $test->run_name, '2345', 'run name is correct');
  is( $test->batch_id, undef, 'batch_id value undef' );
  is( $test->expected_cycle_count, 77, 'expected cycle value correct' );
  is( $test->is_paired, 0, 'is_paired value correct' );
  is( $test->is_indexed, 0, 'is_indexed value correct' );
  is( $test->run_type, 'Cytoprofiling', 'run_type value correct' );
};

subtest 'test run parameters loader exceptions' => sub {
  plan tests => 13;

  throws_ok { Monitor::Elembio::RunParametersParser->new() }
    qr/runfolder_path or runparams_path must be specified/,
    'error if neither runfolder_path or runparams_path is set via the constructor';
  throws_ok { Monitor::Elembio::RunParametersParser
    ->new(runfolder_path => '/unknown')
  } qr/Validation failed for 'NpgTrackingDirectory' with value \/unknown/,
    'error when non-exising runfolder path is given';
  throws_ok { Monitor::Elembio::RunParametersParser
    ->new(runparams_path => 't/RunParameters.json')
  } qr/Validation failed for 'NpgTrackingReadableFile' with value t\/RunParameters.json/,
    'error when non-exising RunParameters.json is given';

  my $test = Monitor::Elembio::RunParametersParser->new(runfolder_path => 't');
  throws_ok { $test->runparams_path }
    qr/Validation failed for 'NpgTrackingReadableFile' with value t\/RunParameters.json/,
    'error building runparams_path attribute - RunParameters.json does not exist';
  
  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_folder = 'AV244103';
  my $run_folder_name = '20250101_AV244103_NT1234567E';
  my $data_folder = catdir('t/data/elembio_staging', $instrument_folder, $run_folder_name);
  my $runfolder_path = catdir($testdir, $instrument_folder, $run_folder_name);
  dircopy($data_folder, $runfolder_path) or die "cannot copy test directory $!";

  my $file = "$runfolder_path/RunParameters.json";
  ok( -e $file, "$file file exists");
  my $time = DateTime->new(
    year => 2025,month => 1,day => 29,hour => 13,minute => 30,second => 0
  )->epoch;
  utime $time, $time, $file; # set the timestamp

  $test = Monitor::Elembio::RunParametersParser->new(
    runfolder_path => $runfolder_path);
  throws_ok{ $test->folder_name }
    qr/Empty[ ]value[ ]in[ ]folder_name/msx,
    'folder name empty';
  throws_ok{ $test->flowcell_id }
    qr/Empty[ ]value[ ]in[ ]flowcell_id/msx,
    'flowcell ID empty';
  throws_ok { $test->instrument_side }
    qr/Run[ ]parameter[ ]Side:[ ]wrong[ ]format[ ]in[ ]RunParameters[.]json/msx,
    'wrong side value';
  throws_ok { $test->lane_count }
    qr/Run[ ]parameter[ ]AnalysisLanes:[ ]No[ ]lane[ ]found/msx,
    'wrong lane count';
  my $date;
  warning_like { $date = $test->date_created }
    qr/Run parameter Date: No value in RunParameters.json/,
    'warning about missing run creation date';
  is( $date->strftime('%Y-%m-%dT%H:%M:%S'), '2025-01-29T13:30:00',
    'missing date has a fallback of RunParameters.json file creation' );
  is( $test->batch_id, undef, 'batch_id is undef');
  is( $test->run_type, undef, 'run_type is undef' );
};

1;
