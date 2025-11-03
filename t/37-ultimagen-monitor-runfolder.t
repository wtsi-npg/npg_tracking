use strict;
use warnings;
use File::Basename;
use File::Copy;
use File::Copy::Recursive qw( dircopy );
use Test::More tests => 5;
use Test::Exception;
use Test::Warn;
use File::Temp qw/ tempdir /;
use File::Path qw/ make_path /;
use File::Spec::Functions qw( catfile catdir );
use File::Slurp;

use t::dbic_util;

use_ok('Monitor::Ultimagen::RunFolder');

subtest 'test run parameters loader' => sub {
  plan tests => 5;

  my $schema = t::dbic_util->new->test_schema();
  my $testdir = tempdir( CLEANUP => 1 );
  my $date = '20250822_0117';
  my $ultimagen_runid = '424090';
  my $run_folder_name = "${ultimagen_runid}-${date}";
  my $data_folder = catdir('t/data/ultimagen_staging/Runs', $run_folder_name);
  my $runfolder_path = catdir($testdir, 'Runs', $run_folder_name);
  dircopy($data_folder, $runfolder_path) or die "cannot copy test directory $!";

  my $test = Monitor::Ultimagen::RunFolder->new(
    runfolder_path      => $runfolder_path,
    npg_tracking_schema => $schema);
  isa_ok( $test, 'Monitor::Ultimagen::RunFolder' );
  is( $test->folder_name, $run_folder_name, 'run_folder value correct' );
  is( $test->ultimagen_runid, $ultimagen_runid, 'ultimagen_runid value correct' );
  is( $test->date_created->strftime('%Y%m%d_%H%M'), $date,
    'date_created value correct' );
  isa_ok( $test->tracking_run(), 'npg_tracking::Schema::Result::Run',
          'Object returned by tracking_run method' );
};

subtest 'test tracking update on new run' => sub {
  plan tests => 18;

  my $schema = t::dbic_util->new->test_schema();
  my $testdir = tempdir( CLEANUP => 1 );
  my $date = '20250822_0117';
  my $ultimagen_runid = '424090';
  my $run_folder_name = "${ultimagen_runid}-${date}";
  my $data_folder = catdir('t/data/ultimagen_staging/Runs', $run_folder_name);
  my $runfolder_path = catdir($testdir, 'Runs', $run_folder_name);
  dircopy($data_folder, $runfolder_path) or die "cannot copy test directory $!";

  my $test = Monitor::Ultimagen::RunFolder->new( runfolder_path      => $runfolder_path,
                                                npg_tracking_schema => $schema);
  lives_ok {$test->process_run();} 'process_run succeeds';
  is( $test->tracking_run()->folder_name, $run_folder_name, 'folder_name of new tracking run' );
  is( $test->tracking_run()->flowcell_id, $ultimagen_runid, 'ultimagen_runid of new tracking run' );
  is( $test->tracking_run()->batch_id, undef, 'undef batch_id of new tracking run' );
  is( $test->tracking_run()->id_instrument, 130, 'id_instrument of new tracking run' );
  is( $test->tracking_run()->id_instrument_format, 25, 'id_instrument_format of new tracking run' );
  isa_ok( $test->tracking_instrument(), 'npg_tracking::Schema::Result::Instrument',
          'Object returned by tracking_instrument method' );
  is( $test->tracking_instrument()->external_name, 'V125', 'external name of the tracking run instrument' );
  is( $test->tracking_run()->team, 'SR', 'team of new tracking run' );
  is( $test->tracking_run()->priority, 1, 'priority of new tracking run' );
  is( $test->tracking_run()->is_paired, 0, 'is_paired of new tracking run' );
  is( $test->tracking_run()->folder_path_glob, dirname($runfolder_path), 'folder_path_glob of new tracking run' );
  my $rs = $test->tracking_run()->current_run_status;
  ok( $rs, 'current_run_status set in new run');
  is( $rs->user->username, 'useq_pipeline', 'status is set by useq_pipeline user');
  is( $test->tracking_run()->current_run_status_description, 'run in progress', 'current_run_status in progress of new run');
  is( 
    $test->tracking_run()->current_run_status->date->strftime('%Y%m%d_%H%M'), 
    $test->date_created->strftime('%Y%m%d_%H%M'),
    'current_run_status date set on run creation in new run');
  ok( $test->tracking_run()->is_tag_set('staging'), 'staging tag of new run is set');
  ok( $test->tracking_run()->is_tag_set('multiplex'), 'multiplex tag of new run is set');
};

subtest 'test on status progress' =>  sub {
  plan tests => 12;

  my $schema = t::dbic_util->new->test_schema();
  my $testdir = tempdir( CLEANUP => 1 );
  my $date = '20250822_0117';
  my $ultimagen_runid = '424090';
  my $run_folder_name = "${ultimagen_runid}-${date}";
  my $data_folder = catdir('t/data/ultimagen_staging/Runs', $run_folder_name);
  my $runfolder_path = catdir($testdir, 'Runs', $run_folder_name);
  my $upload_completed_path = catfile($runfolder_path, 'UploadCompleted.json');
  dircopy($data_folder, $runfolder_path) or die "cannot copy test directory $!";

  my $test = Monitor::Ultimagen::RunFolder->new( runfolder_path      => $runfolder_path,
                                                npg_tracking_schema => $schema);
  ok( ! -e $upload_completed_path, 'new run not completed');
  lives_ok {$test->process_run();} 'process_run succeeds';
  ok( $test->tracking_run()->current_run_status, 'current_run_status set after update');
  is( $test->tracking_run()->current_run_status_description, 'run in progress', 'current_run_status on run in progress');

  open my $fh, '>', $upload_completed_path or die 'cannot create file in test';
  close $fh;
  ok( -e $upload_completed_path, 'UploadCompleted.json exists before process_run' );
  lives_ok {$test->process_run();} 'process_run succeeds on completed run';
  my @run_statuses = sort {
    DateTime->compare($a->date, $b->date)
  } $test->tracking_run()->run_statuses()->all();
  is( @run_statuses, 2, 'correct number of run statuses' );
  is( $run_statuses[0]->description, 'run in progress', 'first run status is run in progress');
  is( $run_statuses[1]->description, 'run mirrored', 'second run status is run mirrored');
  ok(
    DateTime->compare($test->date_created, $test->tracking_run()->current_run_status->date) == -1,
    'run mirrored date more recent than run in progress');

  lives_ok {$test->process_run();} 'process_run succeeds on early return';
  is( $test->tracking_run()->current_run_status_description, 'run mirrored', 'status on run mirrored after early return');
};

subtest 'test exceptions' => sub {
  plan tests => 3;

  my $schema = t::dbic_util->new->test_schema();
  my $testdir = tempdir( CLEANUP => 1 );
  my $date = '20250822_0117';
  my $ultimagen_runid = '424090';
  my $run_folder_name1 = "${ultimagen_runid}-${date}";
  my $run_folder_name2 = "RE-${ultimagen_runid}-${date}";
  my $data_folder = catdir('t/data/ultimagen_staging/Runs', $run_folder_name1);
  my $runfolder_path1 = catdir($testdir, 'Runs', $run_folder_name1);
  my $runfolder_path2 = catdir($testdir, 'Runs', $run_folder_name2);
  dircopy($data_folder, $runfolder_path1) or die "cannot copy test directory $!";
  dircopy($data_folder, $runfolder_path2) or die "cannot copy test directory $!";

  my $test1 = Monitor::Ultimagen::RunFolder->new(
    runfolder_path      => $runfolder_path1,
    npg_tracking_schema => $schema);
  is( $test1->tracking_run()->flowcell_id, $ultimagen_runid, 'ultimagen_runid of new tracking run' );
  is( $test1->folder_name, $run_folder_name1, 'run_folder value correct' );

  $test1 = Monitor::Ultimagen::RunFolder->new(
    runfolder_path      => $runfolder_path2,
    npg_tracking_schema => $schema);
  throws_ok { $test1->tracking_run() }
    qr/Tracking[ ]run[ ]'424090 - 424090-20250822_0117'[ ]has[ ]a[ ]different[ ]folder[ ]name[ ]from[ ]local[ ]folder[ ]'RE-424090-20250822_0117'/,
    'doubled run check correct';
};

1;
