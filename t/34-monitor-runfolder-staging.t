use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;
use Test::Warn;
use File::Copy;
use File::Find;
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;
use Fcntl qw/S_ISGID/;

use t::dbic_util;

my $SECONDS_PER_HOUR = 60 * 60;

BEGIN {
    local $ENV{'HOME'} = 't'; # t/.npg/npg_tracking config file does not contain
                              # analysis_group entry
    use_ok('Monitor::RunFolder::Staging');
}

my $schema = t::dbic_util->new->test_schema();

sub write_run_params {
  my ($id_run, $fs_run_folder) = @_;

  my $runparamsfile = qq[$fs_run_folder/runParameters.xml];
  open(my $fh, '>', $runparamsfile) or die "Could not open file '$runparamsfile' $!";
  print $fh <<"ENDXML";
<?xml version="1.0"?>
<RunParameters xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<Setup>
  <ApplicationName>NovaSeq Control Software</ApplicationName>
  <ExperimentName>$id_run</ExperimentName>
</Setup>
</RunParameters>
ENDXML
  close $fh;
}

sub write_run_files {
  my ($id_run, $fs_run_folder, $lanes, $cycles) = @_;

  $lanes = $lanes || 8;
  if ( $cycles ) {
    $cycles = qq[<Read Number="1" NumCycles="$cycles" IsIndexedRead="N" />];
  } else {
    $cycles = <<"ENDXML";
      <Read Number="1" NumCycles="151" IsIndexedRead="N" />
      <Read Number="2" NumCycles="8" IsIndexedRead="Y" />
      <Read Number="3" NumCycles="151" IsIndexedRead="N" />
ENDXML
  }

  write_run_params($id_run, $fs_run_folder);

  my $runinfofile = qq[$fs_run_folder/RunInfo.xml];
  open(my $fh, '>', $runinfofile) or die "Could not open file '$runinfofile' $!";
  print $fh <<"ENDXML";
<?xml version="1.0"?>
<RunInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="3">
<Run>
  <Reads>
$cycles
  </Reads>
  <FlowcellLayout LaneCount="$lanes" SurfaceCount="2" SwathCount="2" TileCount="24">
  </FlowcellLayout>
</Run>
</RunInfo>
ENDXML
  close $fh;
}

sub touch_file {
    my $path = shift;
    open(my $fh, '>', $path) or die "Could not touch file '$path' $!";
    close $fh;
}

subtest 'computing glob and updating run data from filesystem' => sub {
    plan tests => 7;

    my $rf_name = q[240124_A00951_0713_AHW3TYDRX3];
    my $staging = tempdir( CLEANUP => 1 ) .
        q[/esa-sv-20201215-02/IL_seq_data];
    my $fs_run_folder = $staging . q[/incoming/] . $rf_name;
    make_path($fs_run_folder);
    my $id_run = 1234;
    write_run_files($id_run, $fs_run_folder);

    my $run_data = {
      id_run => $id_run,
      id_instrument => 67,
      id_instrument_format => 10,
      team => 'A',
      expected_cycle_count => 310,
      actual_cycle_count => 0,
    };
    my $run = $schema->resultset('Run')->find($id_run);
    $run->update($run_data);

    my $run_folder = Monitor::RunFolder::Staging->new(
        runfolder_path      => $fs_run_folder,
        npg_tracking_schema => $schema);
    isa_ok($run_folder, 'Monitor::RunFolder::Staging');
    lives_ok { $run_folder->update_run_record } 'update folder name and glob in DB';
    is( $run_folder->tracking_run()->folder_name(), $rf_name,
        'folder name updated' );
    is( $run_folder->tracking_run()->folder_path_glob(),
        $staging . q[/*/], 'folder path glob updated');

    my $glob = '/{export,nfs}/esa-sv-20201215-01/IL_seq_data/*/';
    my $path = '/export/esa-sv-20201215-01/IL_seq_data/outgoing/' . $rf_name;
    for my $dir (qw/incoming analysis outgoing/) {
        my $rfpath = $path;
        $rfpath =~ s/outgoing/$dir/;
        note $rfpath;
        my $test = Monitor::RunFolder::Staging->new(runfolder_path => $rfpath);
        is($test->_get_folder_path_glob, $glob, "glob for /$dir/");
    }
};

subtest 'folder identifies copy complete for NovaSeq' => sub {
    plan tests => 12;

    my $fs_run_folder = tempdir( CLEANUP => 1 ) .
        q[/esa-sv-20201215-02/IL_seq_data/incoming/240124_A00951_0713_AHW3TYDRX3];
    make_path($fs_run_folder);
    my $id_run = 1234;
    write_run_files($id_run, $fs_run_folder);

    my $run_data = {
      id_run => $id_run,
      id_instrument => 67,
      id_instrument_format => 10,
      team => 'A',
      expected_cycle_count => 310,
      actual_cycle_count => 0, # So there is no lag
    };

    my $run = $schema->resultset('Run')->find($id_run);
    $run->update($run_data);

    my $run_folder = Monitor::RunFolder::Staging->new(
        runfolder_path      => $fs_run_folder,
        npg_tracking_schema => $schema);
    ok(!$run_folder->is_run_complete(), 'Run is not complete');

    my $path_to_rta_complete = qq[$fs_run_folder/RTAComplete.txt];
    my $path_to_copy_complete = qq[$fs_run_folder/CopyComplete.txt];

    touch_file($path_to_rta_complete);
    ok(!$run_folder->is_run_complete(),
        'Only RTAComplete is not enough for NovaSeq');

    for my $file_name (qw[CopyComplete Copycomplete
                          copycomplete CopyComplete_old.txt ]) {
        note $file_name;
        my $path_to_wrong_copy_complete = qq[$fs_run_folder/$file_name];
        touch_file($path_to_wrong_copy_complete);
        ok(!$run_folder->is_run_complete(), 'Run is not complete');
        unlink $path_to_wrong_copy_complete or die
            "Could not delete file $path_to_wrong_copy_complete: $!";
    }
    unlink $path_to_rta_complete or die
        "Could not delete file $path_to_rta_complete: $!";

    touch_file($path_to_copy_complete);
    my $complete = 1;
    warning_like { $complete = $run_folder->is_run_complete() }
        { carped => qr/with CopyComplete\.txt but not RTAComplete\.txt/ },
        'Missing RTAComplete.txt is logged';
    is($complete, 0, 'Only CopyComplete.txt file is not enough for NovaSeq');

    touch_file($path_to_rta_complete);
    ok($run_folder->is_run_complete(),
        'RTAComplete + CopyComplete is enough for NovaSeq');
    unlink $path_to_copy_complete or die
        "Could not delete file '$path_to_copy_complete' $!";

    my ($atime, $mtime) = (stat($path_to_rta_complete))[8,9];
    $atime -= 3 * $SECONDS_PER_HOUR; # make it 3 hours ago
    $mtime = $atime;

    utime($atime, $mtime, $path_to_rta_complete)
        or die "couldn't backdate $path_to_rta_complete, $!";
    ok(!$run_folder->is_run_complete(),
        'RTAComplete + short wait time is not enough for NovaSeq');

    ($atime, $mtime) = (stat($path_to_rta_complete))[8,9];
    $atime -= 9 * $SECONDS_PER_HOUR; # make it 12 hours ago
    $mtime = $atime;

    utime($atime, $mtime, $path_to_rta_complete)
        or die "couldn't backdate $path_to_rta_complete, $!";
    $complete = 0;
    warnings_like { $complete = $run_folder->is_run_complete() } [
        { carped => qr/with RTAComplete\.txt but not CopyComplete\.txt/ },
        { carped => qr/Has waited for over 21600 secs, consider copied/ }
    ], 'Missing CopyComplete.txt and end of the wait are logged';
    is($complete, 1, 'RTAComplete + long wait time is enough for NovaSeq');
};

subtest 'counting cycles and tiles' => sub {
    plan tests => 10;

    my $tmpdir = tempdir( CLEANUP => 1 );
    my $bc_path = qq[$tmpdir/Data/Intensities/BaseCalls];
    make_path($bc_path);
    copy('t/data/run_info/runInfo.novaseq.xp.lite.xml', "$tmpdir/RunInfo.xml");    
    copy('t/data/run_params/RunParameters.novaseq.xp.lite.xml',
        "$tmpdir/RunParameters.xml");
    my $ref = {
        id_run => 1234,
        runfolder_path => $tmpdir,
        npg_tracking_schema => $schema
    };

    my $test = Monitor::RunFolder::Staging->new($ref);
    warning_like { $test->check_tiles() }
                 { carped => qr/Missing[ ]lane[(]s[)]/msx },
                 'Report missing lanes';

    map { make_path("$bc_path/L00" . $_) }   qw/1 2/;
    $test = Monitor::RunFolder::Staging->new($ref);
    warning_like { $test->check_tiles() }
                 { carped => qr/Missing[ ]cycle[(]s[)]/msx },
                 'Report missing cycles';

    for my $lane ((1, 2)) {
        for my $cycle ((1, 2, 3)) {
            my $dir = sprintf '%s/L00%i/C%i.1', $bc_path, $lane, $cycle;
            make_path($dir);
        }
    }
    $test = Monitor::RunFolder::Staging->new($ref);
    warning_like { $test->check_tiles() }
                 { carped => qr/Missing\ cbcl\ files/msx },
                 'Report missing files';

    for my $lane ((1, 2)) {
        for my $cycle ((1, 2, 3)) {
            for my $surface ((1,2)) {
                my $file = sprintf '%s/L00%i/C%i.1/L00%i_2.cbcl',
                    $bc_path, $lane, $cycle, $surface;
                `touch $file`;
            }
        }
    }
    $test = Monitor::RunFolder::Staging->new($ref);
    ok ($test->check_tiles(), 'All files present');
 
    is ($test->get_latest_cycle(), 3, 'correct latest cycle');
    my $dir = "$bc_path/L002/C3.1";
    move "$bc_path/L002/C3.1", "$bc_path/L002/C3.XX";
    is ($test->get_latest_cycle(), 3, 'correct current cycle');
    move "$bc_path/L001/C3.1", "$bc_path/L001/C3.XX";
    is ($test->get_latest_cycle(), 2, 'correct current cycle');
    move "$bc_path/L002/C2.1", "$bc_path/L002/C2.XX";
    move "$bc_path/L001/C2.1", "$bc_path/L001/C2.XX";
    is ($test->get_latest_cycle(), 1, 'correct current cycle');
    move "$bc_path/L002/C1.1", "$bc_path/L002/C1.XX";
    is ($test->get_latest_cycle(), 1, 'correct current cycle');
    move "$bc_path/L001/C1.1", "$bc_path/L001/C1.XX";
    is ($test->get_latest_cycle(), 0, 'correct current cycle');
};

subtest 'moving runfolder' => sub {
  plan tests => 32;

    my $tmpdir = tempdir( CLEANUP => 1 );
    my $rf_name = '240125_A01607_0050_AHWF5WDRX3';

    my $test = Monitor::RunFolder::Staging->new(
        runfolder_path => $tmpdir . '/IL_seq_data/skip_this_one/' . $rf_name,
        npg_tracking_schema => $schema);
    throws_ok { $test->move_to_analysis() } qr/is\ not\ in\ incoming/msx,
        'Runfolder should be in incoming';

    $test = Monitor::RunFolder::Staging->new(
        runfolder_path => $tmpdir . '/IL_seq_data/incoming/incoming/' . $rf_name,
        npg_tracking_schema => $schema);
    throws_ok { $test->move_to_analysis() }
        qr/contains\ multiple\ upstream\ incoming\ directories/msx,
        'Runfolder path should not contain multiple incoming directories';

    $test = Monitor::RunFolder::Staging->new(
        runfolder_path      => $tmpdir . '/incoming/' . $rf_name,
        npg_tracking_schema => $schema);
    make_path $tmpdir . '/analysis/' . $rf_name;
    throws_ok { $test->move_to_analysis() } qr/already\ exists/msx,
        'Refuse to overwrite an existing directory';

    $rf_name = '240125_A00708_0693_BH2C2NDSXC';
    my $test_source  = $tmpdir . '/IL_seq_data/incoming/' . $rf_name;
    my $analysis_dir = $tmpdir . '/IL_seq_data/analysis';
    my $test_target  = $analysis_dir . '/' . $rf_name;
    make_path $test_source;
    $schema->resultset('Run')->find(5222)->update_run_status('qc complete');

    $test = Monitor::RunFolder::Staging->new(runfolder_path => $test_source,
                                             id_run => 5222,
                                             npg_tracking_schema => $schema);
    ok( !$test->is_in_analysis(), 'run folder is not in analysis');
    my $m;
    lives_ok { $m = $test->move_to_analysis() } 'Move to analysis';
    ok( -e $test_source, 'Run folder is not gone from incoming' );
    ok( !-e $test_target, 'Run folder is not present in analysis' );

    make_path( $analysis_dir );
    ok( -e $analysis_dir, 'analysis dir exists - test prerequisite');
    lives_ok { $test->move_to_analysis() }
        'No error if analysis directory already exists...';
    ok( !-e $test_source, 'runfolder is gone from incoming' );
    ok(  -e $test_target, 'runfolder is present in analysis' );
    is( $test->tracking_run()->current_run_status_description(),
        'analysis pending', 'Current run status is \'analysis pending\'' );

    $test_source = $test_target;
    my $outgoing_dir = $tmpdir . '/IL_seq_data/outgoing';
    $test_target = $outgoing_dir . '/' . $rf_name;

    $test = Monitor::RunFolder::Staging->new( runfolder_path => $test_source,
                                              id_run => 5222,
                                              npg_tracking_schema => $schema, );
    lives_ok { $m = $test->move_to_outgoing() } 'Move to outgoing lives';
    ok( !-e $test_target, 'not in outgoing' );
    ok( -e $test_source, 'in analysis' );
    is($m, 'Run 5222 status analysis pending is not qc complete, ' .
        'not moving to outgoing',
        'not moved since the run status does not fit');
    sleep 1;
    $test->tracking_run()->update_run_status('qc complete');

    $test = Monitor::RunFolder::Staging->new(
        runfolder_path => $tmpdir . '/IL_seq_data/incoming/' . $rf_name,
        id_run => 5222,
        npg_tracking_schema => $schema);
    throws_ok { $test->move_to_outgoing() } qr/is\ not\ in\ analysis/msx,
        'Runfolder should be in analysis';

    $test = Monitor::RunFolder::Staging->new(
        runfolder_path => $tmpdir . '/IL_seq_data/analysis/some/analysis/' .
                          $rf_name,
        id_run => 5222,
        npg_tracking_schema => $schema);
    throws_ok { $test->move_to_outgoing() }
        qr/contains\ multiple\ upstream\ analysis\ directories/msx,
        'Runfolder path should not contain multiple upstream analysis directories';

    $test = Monitor::RunFolder::Staging->new(runfolder_path => $test_source,
                                             id_run => 5222,
                                             npg_tracking_schema => $schema);
    ok( $test->is_in_analysis(), 'run folder is in analysis');
    lives_ok { $m = $test->move_to_outgoing() } 'Move to outgoing lives';
    ok( !-e $test_target, 'is not in outgoing');
    is( $m, "Failed to move $test_source to $test_target" .
      ': No such file or directory', 'move is confirmed' );
    ok( -e $test_source, 'still in analysis' );

    make_path $outgoing_dir;
    lives_ok { $m = $test->move_to_outgoing() } 'Move to outgoing lives';
    ok( -e $test_target, 'is in outgoing' );
    is( $m, "Moved $test_source to $test_target", 'move is confirmed' );
    ok( !-e $test_source, 'gone from analysis' );
    throws_ok { $test->move_to_outgoing() } qr/already\ exists/msx,
        'Refuse to overwrite an existing directory';

    $tmpdir = tempdir( CLEANUP => 1 );
    $test_source  = $tmpdir . '/IL_seq_data/incoming/' . $rf_name;
    $analysis_dir = $tmpdir . '/IL_seq_data/analysis';
    $test_target  = $analysis_dir . '/' . $rf_name;
    make_path $test_source;
    make_path $analysis_dir;
    $schema->resultset('Run')->find(5222)->update_run_status('run pending');

    $test = Monitor::RunFolder::Staging->new( runfolder_path => $test_source,
                                              id_run => 5222,
                                              status_update => 0,
                                              npg_tracking_schema => $schema);
    lives_ok { $test->move_to_analysis() } 'Move to analysis';
    ok( !-e $test_source, 'runfolder is gone from incoming' );
    ok(  -e $test_target, 'runfolder is present in analysis' );
    is( $test->tracking_run()->current_run_status_description(), 'run pending',
        'run status is unchanged' );
};

subtest 'monitoring size' => sub {
    plan tests => 2;

    my $tmpdir = tempdir( CLEANUP => 1 );
    make_path("$tmpdir/Data/Intensities/Basecalls/L001/C1.1");
    copy('t/data/run_info/runInfo.novaseq.xp.lite.xml', "$tmpdir/RunInfo.xml");
    my $test = Monitor::RunFolder::Staging->new(runfolder_path      => $tmpdir,
                                                npg_tracking_schema => $schema );

    find( sub { utime time, time, $_ }, $tmpdir );
    my $future_time = time + 1_000_000;
    utime $future_time, $future_time, "$tmpdir/RunInfo.xml";

    my ( $size, $date ) = $test->monitor_stats($tmpdir);
    is( $date, $future_time, 'Find latest modification time' );

    # Seems a little fragile (and unnecessary) to insist on an exact match.
    ok( $size > 100, 'Find file size sum' );
};

subtest 'seting file system permissions' => sub {
    plan tests => 4;

    my $tmpdir = tempdir( CLEANUP => 1 );
    my $r= (stat($tmpdir))[2] & S_ISGID();
    ok( !$r, 'initially the gid bit is not set');
    Monitor::RunFolder::Staging::_set_sgid($tmpdir);
    $r= (stat($tmpdir))[2] & S_ISGID();
    ok( $r, 'now the s directory bit');

    $tmpdir = tempdir( CLEANUP => 1 );
    my ($user, $passwd, $uid, $gid ) = getpwuid $< ;
    my $group = getgrgid $gid;
    lives_ok { Monitor::RunFolder::Staging::_change_group($group, $tmpdir, 1) }
       'changing group';
    $r= (stat($tmpdir))[2] & S_ISGID();
    ok( $r, 'now the gid bit is set');
};

subtest 'run completion for NovaSeqX' => sub {
    plan tests => 5;

    my $tmpdir = tempdir( CLEANUP => 1 );
    copy('t/data/run_params/RunParameters.novaseqx.xml',"$tmpdir/RunParameters.xml")
      or die "Copy failed: $!";
    copy('t/data/run_info/runInfo.novaseqx.xml',"$tmpdir/RunInfo.xml")
      or die "Copy failed: $!";

    my $monitor = Monitor::RunFolder::Staging->new(runfolder_path => $tmpdir);
    ok (!$monitor->is_run_complete(), 'run is not complete');

    my $copy_complete_file = "$tmpdir/CopyComplete.txt";
    touch_file($copy_complete_file);
    my $rta_complete_file = "$tmpdir/RTAComplete.txt";
    touch_file($rta_complete_file);
    ok ($monitor->is_run_complete(), 'run is complete');
    unlink $copy_complete_file;
    ok (!$monitor->is_run_complete(), 'run is not complete');    
    
    my ($atime, $mtime) = (stat($rta_complete_file))[8,9];
    $atime -= 12 * $SECONDS_PER_HOUR; # make it 12 hours ago
    $mtime = $atime;
    utime($atime, $mtime, $rta_complete_file)
        or die "couldn't backdate $rta_complete_file, $!";

    my $complete = 0;
    warnings_like { $complete = $monitor->is_run_complete() } [
        { carped => qr/with RTAComplete\.txt but not CopyComplete\.txt/ },
        { carped => qr/Has waited for over 21600 secs, consider copied/ }
    ], 'Missing CopyComplete.txt and end of the wait are logged';
    ok( $complete,
        'RTAComplete + long wait time is enough for NovaSeqX');
};

subtest 'onboard analysis completion for NovaSeqX' => sub {
    plan tests => 6;

    my $tmpdir = tempdir( CLEANUP => 1 );
    copy('t/data/run_params/RunParameters.novaseqx.xml',"$tmpdir/RunParameters.xml")
      or die "Copy failed: $!";
    copy('t/data/run_info/runInfo.novaseqx.xml',"$tmpdir/RunInfo.xml")
      or die "Copy failed: $!";

    my $monitor = Monitor::RunFolder::Staging->new(runfolder_path => $tmpdir);
    
    ok (!$monitor->onboard_analysis_planned(),
        'onboard analysis is not planned');
    ok (!$monitor->is_onboard_analysis_output_copied(),
        'onboard analysis has not been copied');

    copy('t/data/run_params/RunParameters.novaseqx.onboard.xml',
      "$tmpdir/RunParameters.xml") or die "Copy failed: $!";
    my $adir = "$tmpdir/Analysis";
    mkdir $adir;
    $monitor = Monitor::RunFolder::Staging->new(runfolder_path => $tmpdir);
    ok ($monitor->onboard_analysis_planned(), 'onboard analysis is planned');
    ok (!$monitor->is_onboard_analysis_output_copied(),
        'onboard analysis has not been copied');
 
    mkdir "$adir/2"; 
    `touch $adir/2/CopyComplete.txt`;
    ok (!$monitor->is_onboard_analysis_output_copied(),
        'onboard analysis has not been copied');

    mkdir "$adir/1";
    `touch $adir/1/CopyComplete.txt`;
    ok ($monitor->is_onboard_analysis_output_copied(),
      'onboard analysis has been copied');     
};

1;
