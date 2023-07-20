use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;
use File::Path qw/make_path/;
use File::Copy;
use File::Temp qw/ tempdir /;

use t::dbic_util;

use_ok('Monitor::RunFolder::Staging');

#########
# Tests for high-level functionality, ie the update_run_from_path method
# of the Monitor::RunFolder::Staging class. In these tests the class
# instances are created the same way as in the staging_area_monitor script,
# i.e. by supplying the runfolder_path and npg_tracking_schema attributes.
#
# Tests are arranged roughly in the way the code flows. Each subtest
# corresponds to one loop of the staging monitor.
#

my $schema = t::dbic_util->new->test_schema(); # t/data/dbic_fixtures
my $dir = tempdir( CLEANUP => 1 );

my $idir = "$dir/incoming";
my $adir = "$dir/analysis";
my $odir = "$dir/outgoing";
make_path($idir, $adir, $odir);

# Create bare-bones NovaSeqXPlus run.
my $id_run = 47539;
my $run = $schema ->resultset('Run')->create({
  id_run => $id_run,
  expected_cycle_count => 8,
  actual_cycle_count   => 0,
  id_instrument => 70,
  id_instrument_format => 13,
  team => 'A'
});
$run->update_run_status('run pending');

my $runfolder_name = q[20230628_LH00210_0008_B225TGJLT3];
# The runfolder is originally in 'incoming'
my $runfolder_path = join q[/], $idir, $runfolder_name;
make_path($runfolder_path);
my $basecalls_path = "$runfolder_path/Data/Intensities/BaseCalls";

copy 't/data/test_staging_daemon/novaseqxplus/RunInfo.xml',
  "$runfolder_path/RunInfo.xml";
copy 't/data/test_staging_daemon/novaseqxplus/RunParameters.xml',
  "$runfolder_path/RunParameters.xml";

subtest 'a new run in incoming' => sub {
  plan tests => 15;

  my $monitor = Monitor::RunFolder::Staging->new(
    runfolder_path => $runfolder_path,
    npg_tracking_schema => $schema
  );
  my $size_hash = {};
  my $done;
  lives_ok { $done = $monitor->update_run_from_path($size_hash) } 'run the monitor';
  ok (!$done, 'correct return value');
  ok (defined $monitor->tracking_run(), 'run row is cached');
  my $tracking_run = $monitor->tracking_run();
  is ($tracking_run->id_run, $id_run, 'correct db record is cached');
  is ($tracking_run->folder_name(), $runfolder_name,
    'tracking database - run folder name is set');
  is ($tracking_run->folder_path_glob(), "$dir/*/",
    'tracking database - run folder glob is set');
  is ($tracking_run->actual_cycle_count(), 0, 'cycle count is zero');
  is ($tracking_run->current_run_status_description(), 'run pending',
    'the run is still pending');
  is ($tracking_run->flowcell_id(), '225TGJLT3',
    'flowcell barcode is recorded');
  ok ($tracking_run->is_tag_set('staging'), 'staging tag is set');
  ok ($tracking_run->is_tag_set('fc_slotB'), 'instrument side B is set');
  ok ($tracking_run->is_tag_set('paired_read'), 'run is tagged as paired');
  ok ($tracking_run->is_tag_set('multiplex'), 'run is tagged as multiplex');
  ok (exists $size_hash->{$runfolder_path}, 'runfolder size is cached');
  is ($size_hash->{$runfolder_path}, 0, 'runfolder size is set to zero');
};

subtest 'run in progress' => sub {
  plan tests => 10;

  # Now the run is half way through to completion.
  for my $i ((1 .. 8)) {
    for my $j ((1 .. 4)) {
      make_path("$basecalls_path/L00${i}/C${j}.1");
    }
  }
  my $monitor = Monitor::RunFolder::Staging->new(
    runfolder_path => $runfolder_path,
    npg_tracking_schema => $schema
  );
  my $size_hash = {$runfolder_path => 0};
  my $done;
  lives_ok { $done = $monitor->update_run_from_path($size_hash) } 'run the monitor';
  ok (!$done, 'correct return value');
  is ($monitor->tracking_run->actual_cycle_count(), 4, 'cycle count is 4');
  is ($monitor->tracking_run->current_run_status_description(), 'run in progress',
    'the run is in progress');
  is ($size_hash->{$runfolder_path}, 0, 'runfolder size is zero');

  # Now the run is close to completion.
  for my $i ((1 .. 8)) {
    for my $j ((5 .. 8)) {
      make_path("$basecalls_path/L00${i}/C${j}.1");
    }
  }
  $monitor = Monitor::RunFolder::Staging->new(
    runfolder_path => $runfolder_path,
    npg_tracking_schema => $schema
  );
  lives_ok { $done = $monitor->update_run_from_path($size_hash) } 'run the monitor';
  ok (!$done, 'correct return value');
  is ($monitor->tracking_run->actual_cycle_count(), 8, 'cycle count is 8');
  is ($monitor->tracking_run->current_run_status_description(), 'run in progress',
    'the run is in progress');
  is ($size_hash->{$runfolder_path}, 0, 'runfolder size is zero');
};

subtest 'run is completed' => sub {
  plan tests => 5;

  for my $f (qw(RTAComplete.txt CopyComplete.txt)) {
    `touch $runfolder_path/$f`;
  }

  my $monitor = Monitor::RunFolder::Staging->new(
    runfolder_path => $runfolder_path,
    npg_tracking_schema => $schema
  );
  my $size_hash = {$runfolder_path => 0};
  my $done;
  lives_ok { $done = $monitor->update_run_from_path($size_hash) } 'run the monitor';
  ok (!$done, 'correct return value');
  is ($monitor->tracking_run->actual_cycle_count(), 8, 'cycle count is 8');
  is ($monitor->tracking_run->current_run_status_description(), 'run complete',
    'the run has completed');
  is ($size_hash->{$runfolder_path}, 0, 'runfolder size is zero');
};

subtest 'run is mirrored' => sub {
  plan tests => 10;

  for my $i ((1 .. 8)) {
    for my $j ((1 .. 8)) {
      for my $s ((1 .. 2)) {
        `touch $basecalls_path/L00${i}/C${j}.1/L00${i}_${s}.cbcl`;
      }
    }
  }
  my $monitor = Monitor::RunFolder::Staging->new(
    runfolder_path => $runfolder_path,
    npg_tracking_schema => $schema
  );
  my $size_hash = {$runfolder_path => 0};
  my $done;
  lives_ok { $done = $monitor->update_run_from_path($size_hash) } 'run the monitor';
  ok (!$done, 'correct return value');
  my $size = $size_hash->{$runfolder_path};
  ok ($size > 0, 'runfolder size is not zero');
  is ($monitor->tracking_run->current_run_status_description(), 'run complete',
    'the run is still marked as completed');

  $monitor = Monitor::RunFolder::Staging->new(
    runfolder_path => $runfolder_path,
    npg_tracking_schema => $schema
  );
  lives_ok { $done = $monitor->update_run_from_path($size_hash) } 'run the monitor';
  ok ($done, 'correct return value');
  is ($size_hash->{$runfolder_path}, $size, 'runfolder size does not change');
  is ($monitor->tracking_run->current_run_status_description(), 'analysis pending',
    'the run is marked as mirrored and automatically moved to pending analysis');
  ok (!-e $runfolder_path, 'the old run folder path is invalid');
  $runfolder_path = join q[/], $adir, $runfolder_name;
  ok (-e $runfolder_path, q[the folder has been moved to 'analysis']);
};

subtest q[move to 'outgoing'] => sub {
  plan tests => 10;

  # Run is now in the 'analysis' directory'
  $run->update_run_status('secondary analysis in progress');
  my $monitor = Monitor::RunFolder::Staging->new(
    runfolder_path => $runfolder_path,
    npg_tracking_schema => $schema
  );
  my $done;
  lives_ok { $done = $monitor->update_run_from_path({}) } 'run the monitor';
  ok (!$done, 'correct return value');
  ok (-e $runfolder_path, q[run folder is still in 'analysis']);

  $run->update_run_status('qc complete');
  $monitor = Monitor::RunFolder::Staging->new(
    runfolder_path => $runfolder_path,
    npg_tracking_schema => $schema
  );
  my $inhibit_folder_move = 1;
  lives_ok { $done = $monitor->update_run_from_path({}, $inhibit_folder_move ) }
    'run the monitor';
  ok (!$done, 'correct return value');
  ok (-e $runfolder_path, q[run folder is still in 'analysis']);

  lives_ok { $done = $monitor->update_run_from_path({}) } 'run the monitor';
  ok (!$done, 'correct return value');
  ok (!-e $runfolder_path, 'the old run folder path is invalid');
  $runfolder_path = join q[/], $odir, $runfolder_name;
  ok (-e $runfolder_path, q[the folder has been moved to 'outgoing']);
};

subtest q[wait for DRAGEN analysis to finish] => sub {
  plan tests => 13;

  # Change the run status.
  sleep 1; # Ensure a different timestamp for the new status.
  $run->update_run_status('run complete');

  my $new_path = join q[/], $idir, $runfolder_name;
  `mv $runfolder_path $new_path`; # Move the run folder back to 'incoming'.
  $runfolder_path = $new_path;
  # Copy the file with the DRAGEN analysis section.
  copy('t/data/run_params/RunParameters.novaseqx.onboard.xml',
    "$runfolder_path/RunParameters.xml");
  my $dpath = "$runfolder_path/Analysis/1";
  make_path($dpath); # Create DRAGEN analysis directory.

  my $monitor = Monitor::RunFolder::Staging->new(
    runfolder_path => $runfolder_path,
    npg_tracking_schema => $schema
  );
  my $size_hash = {$runfolder_path => 0};
  my $done;
  lives_ok { $done = $monitor->update_run_from_path($size_hash) }
    'run the monitor';
  ok (!$done, 'correct return value');
  ok ($monitor->onboard_analysis_planned(), 'onboard analysis is planned');
  ok (!$monitor->is_onboard_analysis_output_copied(),
    'onboard analysis data is not copied across yet');
  ok (-e $runfolder_path, q[run folder is in 'incoming']);
  my $size = $size_hash->{$runfolder_path};

  $monitor = Monitor::RunFolder::Staging->new(
    runfolder_path => $runfolder_path,
    npg_tracking_schema => $schema
  );
  lives_ok { $done = $monitor->update_run_from_path($size_hash) } 'run the monitor';
  ok (!$done, 'correct return value');
  ok (-e $runfolder_path, q[run folder is still in 'incoming']);
  ok ($size_hash->{$runfolder_path} == $size, 'the run folder size is stable');
  ok (!$monitor->is_onboard_analysis_output_copied(),
    'onboard analysis data is not copied across yet');

  # Mark DRAGEN analysis as copied across.
  open my $fh, q[>], "$dpath/CopyComplete.txt" or die 'Cannot open the file';
  print $fh 'Mark DRAGEN analysis as copied' or die 'Cannot write';
  close $fh or die 'Cannot close the filehandle';

  $monitor = Monitor::RunFolder::Staging->new(
    runfolder_path => $runfolder_path,
    npg_tracking_schema => $schema
  );
  lives_ok { $done = $monitor->update_run_from_path($size_hash) } 'run the monitor';
  # Sometimes the runfolder size comes out differently at this point,
  # and and extra round is needed.
  if (!$done) {
    $monitor->update_run_from_path($size_hash);
  }
  ok (!-e $runfolder_path, 'the old run folder path is invalid');
  $runfolder_path = join q[/], $adir, $runfolder_name;
  ok (-e $runfolder_path, q[the folder has been moved to 'analysis']);
};

1;



