use strict;
use warnings;
use File::Copy::Recursive qw( dircopy );
use File::Spec::Functions qw( catdir );
use File::Temp qw( tempdir );
use Test::More tests => 3;
use Test::Exception;
use Test::Warn;

use_ok('Monitor::Ultimagen::RunParser');

subtest 'test run parser' => sub {
  plan tests => 5;

  my $testdir = tempdir( CLEANUP => 1 );
  my $date = '20250822_0117';
  my $ultimagen_runid = '424090';
  my $run_folder_name = "${ultimagen_runid}-${date}";
  my $data_folder = catdir('t/data/ultimagen_staging/Runs', $run_folder_name);
  my $runfolder_path = catdir($testdir, 'Runs', $run_folder_name);
  dircopy($data_folder, $runfolder_path) or die "cannot copy test directory $!";

  my $test = Monitor::Ultimagen::RunParser->new(
    runfolder_path => $runfolder_path);
  isa_ok( $test, 'Monitor::Ultimagen::RunParser' );
  is( $test->folder_name, $run_folder_name, 'run_folder_name value correct' );
  is( $test->date_created->strftime('%Y%m%d_%H%M'), $date,
    'date_created value correct' );
  is( $test->ultimagen_runid, $ultimagen_runid, 'ultimagen_runid value correct' );
  is( $test->runfolder_glob, catdir($testdir, 'Runs'), 'run folder glob correct');
};

subtest 'test run parser exceptions' => sub {
  plan tests => 4;

  throws_ok { Monitor::Ultimagen::RunParser->new() }
    "Moose::Exception::AttributeIsRequired",
    'runfolder_path not set';
  throws_ok { Monitor::Ultimagen::RunParser->new(runfolder_path => 'notadirectory') }
    "Moose::Exception::ValidationFailedForTypeConstraint",
    'non-existing runfolder path is given';

  my $testdir = tempdir( CLEANUP => 1 );
  my $date = '20250911_1212';
  my $ultimagen_runid = '222222';
  my $run_folder_name = "${ultimagen_runid}-${date}";
  my $nodate_folder_name = "${ultimagen_runid}_1212";
  my $data_folder = catdir('t/data/ultimagen_staging/Runs', $run_folder_name);
  my $runfolder_path = catdir($testdir, 'Runs', $nodate_folder_name);
  dircopy($data_folder, $runfolder_path) or die "cannot copy test directory $!";

  my $test = Monitor::Ultimagen::RunParser->new(
    runfolder_path => $runfolder_path);
  throws_ok{ $test->ultimagen_runid }
    qr/Empty[ ]value[ ]in[ ]RunId/msx,
    'flowcell ID empty';
  throws_ok { $test->date_created }
    qr/Cannot[ ]extract[ ]run[ ]date[ ]from[ ]run[ ]folder[ ]name[ ]222222_1212/,
    'missing run creation date in folder name';
};
