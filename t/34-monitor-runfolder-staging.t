use strict;
use warnings;
use Test::More tests => 73;
use Test::Exception;
use Test::Warn;
use Test::Deep;
use File::Copy;
use File::Find;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Fcntl qw/S_ISGID/;

use t::dbic_util;

my $MOCK_STAGING = 't/data/gaii/staging';

BEGIN {
    local $ENV{'HOME'} = 't'; # t/.npg/npg_tracking config file does not contain
                              # analysis_group entry
    use_ok('Monitor::RunFolder::Staging');
}

my $schema = t::dbic_util->new->test_schema();

sub write_run_params {
  my ($id_run, $fs_run_folder, $application_name) = @_;
  my $runparamsfile = qq[$fs_run_folder/runParameters.xml];
  open(my $fh, '>', $runparamsfile) or die "Could not open file '$runparamsfile' $!";
  print $fh <<"ENDXML";
<?xml version="1.0"?>
<RunParameters xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<Setup>
  <ApplicationName>$application_name</ApplicationName>
  <ExperimentName>$id_run</ExperimentName>
</Setup>
</RunParameters>
ENDXML
  close $fh;
}

sub write_hiseq_run_params {
  my ($id_run, $fs_run_folder) = @_;
  my $application_name = q[HiSeq Control Software];
  write_run_params($id_run, $fs_run_folder, $application_name);
}

sub write_nova_run_params {
  my ($id_run, $fs_run_folder) = @_;
  my $application_name = q[NovaSeq Control Software];
  write_run_params($id_run, $fs_run_folder, $application_name);
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

  write_hiseq_run_params($id_run, $fs_run_folder);

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

{
    my $test;
    my $mock_path = $MOCK_STAGING . '/IL4/incoming/101026_IL4_0095';

    lives_ok {
           $test = Monitor::RunFolder::Staging->new(
                    runfolder_path      => $mock_path,
                    npg_tracking_schema => $schema)
         }
         'Object creation ok';
    is($test->rta_complete_wait, 600, 'default rta complete wait time');
}

subtest 'updating run data from filesystem' => sub {
    plan tests => 6;
    my $basedir = tempdir( CLEANUP => 1 );

    my $fs_run_folder = qq[$basedir/IL3/incoming/100622_IL3_01234];
    make_path($fs_run_folder);

    my $id_run = 1234;
    my $run_data = {
      id_run => $id_run,
      id_instrument => 67,
      id_instrument_format => 10,
      team => 'A',
      expected_cycle_count => 310,
      actual_cycle_count => 0, # So there is no lag
    };

    write_run_files($id_run, $fs_run_folder);

    my $run = $schema->resultset('Run')->find($id_run);
    $run->update($run_data);

    my $run_folder = Monitor::RunFolder::Staging->new(runfolder_path      => $fs_run_folder,
                                                      npg_tracking_schema => $schema);

    is( $run_folder->_get_folder_path_glob, qq[$basedir/IL3/*/],
        'internal glob correct' );

    lives_ok { $run_folder->update_folder } 'update folder name and glob in DB';
    is( $run_folder->tracking_run()->folder_name(), '100622_IL3_01234',
        '  folder name updated' );
    is( $run_folder->tracking_run()->folder_path_glob(), qq[$basedir/IL3/*/],
        '  folder path glob updated' );
    is( $run_folder->cycle_lag(), 0, 'Mirroring is not lagging' );
    $run->actual_cycle_count(20); # To produce lag
    $run->update();

    $run_folder = Monitor::RunFolder::Staging->new(runfolder_path      => $fs_run_folder,
                                                   npg_tracking_schema => $schema);
    is( $run_folder->cycle_lag(), 1, 'Mirroring is lagging' );
};

{
    my $tmpdir = tempdir( CLEANUP => 1 );

    system('cp',  '-rp', $MOCK_STAGING . '/ILorHSany_sf20/incoming/100914_HS3_05281_A_205MBABXX', $tmpdir);
    sleep 5;

    my $mock_path = $tmpdir . '/100914_HS3_05281_A_205MBABXX';

    my $test = Monitor::RunFolder::Staging->new(runfolder_path      => $mock_path,
                                                npg_tracking_schema => $schema,
                                                rta_complete_wait   => 15);

    rename "$mock_path/RTAComplete.txt", "$mock_path/RTA_renamed_Complete.txt";

    ok( !$test->mirroring_complete(),
        'Mirroring is not complete' );

    rename "$mock_path/RTA_renamed_Complete.txt", "$mock_path/RTAComplete.txt";

    ok( $test->mirroring_complete(),
        'Mirroring is complete' );
}

sub touch_file {
    my ($path) = @_;

    open(my $fh, '>', $path) or die "Could not touch file '$path' $!";
    close $fh;
}

subtest 'folder identifies copy complete for HiSeq (Non-NovaSeq)' => sub {
    plan tests => 7;
    my $basedir = tempdir( CLEANUP => 1 );

    my $fs_run_folder = qq[$basedir/IL3/incoming/100622_IL3_01234];
    make_path($fs_run_folder);

    my $id_run = 1234;
    my $run_data = {
      id_run => $id_run,
      id_instrument => 67,
      id_instrument_format => 10,
      team => 'A',
      expected_cycle_count => 310,
      actual_cycle_count => 0, # So there is no lag
    };

    write_run_files($id_run, $fs_run_folder);

    my $run = $schema->resultset('Run')->find($id_run);
    $run->update($run_data);

    my $run_folder = Monitor::RunFolder::Staging->new(runfolder_path      => $fs_run_folder,
                                                      npg_tracking_schema => $schema);

    ok(!$run_folder->is_run_complete(), 'Run is not complete');

    for my $file_name (qw[ RTAComplete RTAcomplete rtacomplete RTAComplete.tsv RTAComplete_old.txt ]) {
      note $file_name;
      my $path_to_complete = qq[$fs_run_folder/$file_name];
      touch_file($path_to_complete);
      ok(!$run_folder->is_run_complete(), 'Run is not complete');
      unlink $path_to_complete or die "Could not delete file $path_to_complete: $!";
    }

    my $path_to_complete = qq[$fs_run_folder/RTAComplete.txt];
    touch_file($path_to_complete);
    ok($run_folder->is_run_complete(), 'Run is complete');
};

subtest 'folder identifies copy complete for NovaSeq' => sub {
    plan tests => 11;
    my $basedir = tempdir( CLEANUP => 1 );

    my $fs_run_folder = qq[$basedir/IL3/incoming/100622_IL3_01234];
    make_path($fs_run_folder);

    my $id_run = 1234;
    my $run_data = {
      id_run => $id_run,
      id_instrument => 67,
      id_instrument_format => 10,
      team => 'A',
      expected_cycle_count => 310,
      actual_cycle_count => 0, # So there is no lag
    };

    write_run_files($id_run, $fs_run_folder);
    write_nova_run_params($id_run, $fs_run_folder);

    my $run = $schema->resultset('Run')->find($id_run);
    $run->update($run_data);

    my $run_folder = Monitor::RunFolder::Staging->new(runfolder_path      => $fs_run_folder,
                                                      npg_tracking_schema => $schema);

    ok(!$run_folder->is_run_complete(), 'Run is not complete');

    my $path_to_rta_complete = qq[$fs_run_folder/RTAComplete.txt];
    my $path_to_copy_complete = qq[$fs_run_folder/CopyComplete.txt];

    touch_file($path_to_rta_complete);
    ok(!$run_folder->is_run_complete(), 'Only RTAComplete is not enough for NovaSeq');

    for my $file_name (qw[ CopyComplete Copycomplete copycomplete CopyComplete.tsv CopyComplete_old.txt ]) {
      note $file_name;
      my $path_to_wrong_copy_complete = qq[$fs_run_folder/$file_name];
      touch_file($path_to_wrong_copy_complete);
      ok(!$run_folder->is_run_complete(), 'Run is not complete');
      unlink $path_to_wrong_copy_complete or die "Could not delete file $path_to_wrong_copy_complete: $!";
    }

    unlink $path_to_rta_complete or die "Could not delete file $path_to_rta_complete: $!";

    touch_file($path_to_copy_complete);
    ok(!$run_folder->is_run_complete(), 'Only CopyComplete is not enough for NovaSeq');

    touch_file($path_to_rta_complete);
    ok($run_folder->is_run_complete(), 'RTAComplete + CopyComplete is enough for NovaSeq');

    unlink $path_to_copy_complete or die "Could not delete file '$path_to_copy_complete' $!";

    my $SECONDS_PER_HOUR = 60 * 60;
    my ($atime, $mtime) = (stat($path_to_rta_complete))[8,9];
    $atime -= 3 * $SECONDS_PER_HOUR; # make it 3 hours ago
    $mtime = $atime;

    utime($atime, $mtime, $path_to_rta_complete)
        or die "couldn't backdate $path_to_rta_complete, $!";
    ok(!$run_folder->is_run_complete(), 'RTAComplete + short wait time is not enough for NovaSeq');

    ($atime, $mtime) = (stat($path_to_rta_complete))[8,9];
    $atime -= 9 * $SECONDS_PER_HOUR; # make it 12 hours ago
    $mtime = $atime;

    utime($atime, $mtime, $path_to_rta_complete)
        or die "couldn't backdate $path_to_rta_complete, $!";
    ok($run_folder->is_run_complete(), 'RTAComplete + long wait time is enough for NovaSeq');
};

{
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $mock_path = qq[$tmpdir/IL12/incoming];
    make_path($mock_path);

    system('cp',  '-rp', $MOCK_STAGING . '/IL12/incoming/100721_IL12_05222', $mock_path);
    sleep 5;
    $mock_path = qq[$mock_path/100721_IL12_05222];
    my $id_run = 5222;
    write_run_files($id_run, $mock_path);

    my $test = Monitor::RunFolder::Staging->new(runfolder_path      => $mock_path,
                                                npg_tracking_schema => $schema);

    warning_like { $test->check_tiles() }
                 { carped => qr/Missing[ ]lane[(]s[)]/msx },
                 'Report missing lanes';

    my $tmpdir2 = tempdir( CLEANUP => 1 );
    $mock_path = qq[$tmpdir2/IL3/incoming];
    make_path($mock_path);

    system('cp',  '-rp', $MOCK_STAGING . '/IL3/incoming/100622_IL3_01234/', $mock_path);
    sleep 5;
    $mock_path = qq[$mock_path/100622_IL3_01234];
    $id_run = 1234;
    my $lanes = 2;

    write_run_files($id_run, $mock_path);

    $test = Monitor::RunFolder::Staging->new(runfolder_path      => $mock_path,
                                             npg_tracking_schema => $schema);

    warning_like { $test->check_tiles() }
                 { carped => qr/Missing[ ]cycle[(]s[)]/msx },
                 'Report missing cycles';

    my $tmpdir3 = tempdir( CLEANUP => 1 );
    $mock_path = qq[$tmpdir3/IL5/incoming];
    make_path($mock_path);

    system('cp', '-rp', $MOCK_STAGING . '/IL5/incoming/100621_IL5_01204', $mock_path);
    sleep 5;
    $mock_path = qq[$mock_path/100621_IL5_01204];
    $id_run = 1204;
    my $lanes_1204 = 2;
    my $cycles = 3;

    write_run_files($id_run, $mock_path, $lanes_1204, $cycles);

    $test = Monitor::RunFolder::Staging->new(runfolder_path => $mock_path,
                                             npg_tracking_schema => $schema);

    warning_like { $test->check_tiles() }
                 { carped => qr/Missing[ ]tile[(]s[)]/msx },
                 'Report missing tiles';


    my $tmpdir4 = tempdir( CLEANUP => 1 );
    $mock_path = qq[$tmpdir4/IL5/incoming];
    make_path($mock_path);

    system('cp',  '-rp', $MOCK_STAGING . '/IL5/incoming/100708_IL3_04999', $mock_path);
    sleep 5;
    $mock_path = qq[$mock_path/100708_IL3_04999];
    $id_run = 4999;

    write_run_files($id_run, $mock_path);

    $test = Monitor::RunFolder::Staging->new(runfolder_path      => $mock_path,
                                             npg_tracking_schema => $schema);

    lives_ok { $test->check_tiles() } 'All cif files present';
}

{
    my $mock_path = $MOCK_STAGING . '/IL5/incoming/100708_IL3_04999';
    my $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              npg_tracking_schema        => $schema, );


    # Make sure that our initial set up is ok, and that any changes are made
    # by the tests in this section.


    ok( !-e "$mock_path/Mirror.completed", 'Flag file does not exist' );
    isnt( $test->current_run_status_description(), 'run mirrored',
          '\'run mirrored\' status not set' );

    lives_ok { $test->mark_as_mirrored() } 'Mark as mirrored';

    ok( -e "$mock_path/Mirror.completed", 'Now the flag file does exist...' );

    is( $test->current_run_status_description(), 'run mirrored',
          '   ...and the \'run mirrored\' status is set' );

    my $first_flag_mtime = ( stat "$mock_path/Mirror.completed" )[9];
    sleep 1;
    lives_ok { $test->mark_as_mirrored() } 'Repeat mark as mirrored...';

    my $second_flag_mtime = ( stat "$mock_path/Mirror.completed" )[9];

    ok( $first_flag_mtime < $second_flag_mtime,
        '   ...flag file has been touched' );

    my $f = "$mock_path/Mirror.completed";
    if (-e $f) { unlink $f;}

    my @missing_cycles;
    lives_ok { @missing_cycles = $test->missing_cycles($mock_path); } q{missing_cycles ran ok};
    is( scalar @missing_cycles, 0, q{no cycles missing} );
    $test->{_cycle_numbers}->{$mock_path} = [ 1..3, 7..89, 100..120 ];
    @missing_cycles = $test->missing_cycles($mock_path);
    is_deeply( \@missing_cycles, [ 4..6, 90..99 ], q{missing cycles produced ok} );
    is_deeply( $test->{_cycle_numbers}, {}, q{cache removed since acted upon} );
}

{
    my $test = Monitor::RunFolder::Staging->new(
      runfolder_path      => $MOCK_STAGING . '/IL3/skip_this_one/090810_IL12_3289',
      npg_tracking_schema => $schema);
    throws_ok { $test->move_to_analysis() } qr/is\ not\ in\ incoming/msx,
              'Runfolder should be in incoming';

    $test = Monitor::RunFolder::Staging->new(
      runfolder_path      => $MOCK_STAGING . '/IL3/incoming/incoming/090810_IL12_3289',
      npg_tracking_schema => $schema);
    throws_ok { $test->move_to_analysis() } qr/contains\ multiple\ upstream\ incoming\ directories/msx,
              'Runfolder path should not contain multiple incoming directories';

    my $tmpdir = tempdir( CLEANUP => 1 );
    $test = Monitor::RunFolder::Staging->new(
      runfolder_path      => $tmpdir . '/incoming/090810_IL12_3289',
      npg_tracking_schema => $schema);
    make_path $tmpdir . '/analysis/090810_IL12_3289';
    throws_ok { $test->move_to_analysis() } qr/already\ exists/msx,
              'Refuse to overwrite an existing directory';
}

{
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $test_source  = $tmpdir . '/IL12/incoming/100721_IL12_05222';
    my $analysis_dir = $tmpdir . '/IL12/analysis';
    my $test_target  = $analysis_dir . '/100721_IL12_05222';
    make_path $test_source;

    ok( !-e $analysis_dir, 'analysis dir does not exist - test prerequisite');
    $schema->resultset('Run')->find(5222)->update_run_status('qc complete');
    my $test = Monitor::RunFolder::Staging->new( runfolder_path      => $test_source,
                                                 npg_tracking_schema => $schema, );

    isnt( $test->current_run_status_description(), 'analysis pending',
      'run status is not analysis pending');
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

    is( $test->current_run_status_description(), 'analysis pending',
          'Current run status is \'analysis pending\'' );

    $test_source = $test_target;
    my $outgoing_dir = $tmpdir . '/IL12/outgoing';
    $test_target = $outgoing_dir . '/100721_IL12_05222';
    ok( !-e $test_target, 'outgoing run dir does not exist - test prerequisite');
    $test = Monitor::RunFolder::Staging->new( runfolder_path      => $test_source,
                                              npg_tracking_schema => $schema, );

    lives_ok { $m = $test->move_to_outgoing() } 'Move to outgoing lives';
    ok( !-e $test_target, 'not in outgoing' );
    ok( -e $test_source, 'in analysis' );
    is( $m, 'Run 5222 status analysis pending is not qc complete, not moving to outgoing',
      'not moved since the run status does not fit');
    sleep 1;
    $test->tracking_run()->update_run_status('qc complete');

    $test = Monitor::RunFolder::Staging->new(runfolder_path      => $tmpdir . '/IL12/incoming/100721_IL12_05222',
                                             npg_tracking_schema => $schema, );
    throws_ok { $test->move_to_outgoing() } qr/is\ not\ in\ analysis/msx,
              'Runfolder should be in analysis';

    $test = Monitor::RunFolder::Staging->new(
      runfolder_path      => $tmpdir . '/IL12/analysis/some/analysis/100721_IL12_05222',
      npg_tracking_schema => $schema);
    throws_ok { $test->move_to_outgoing() } qr/contains\ multiple\ upstream\ analysis\ directories/msx,
              'Runfolder path should not contain multiple upstream analysis directories';

    $test = Monitor::RunFolder::Staging->new( runfolder_path      => $test_source,
                                              npg_tracking_schema => $schema, );
    ok( $test->is_in_analysis(), 'run folder is in analysis');
    lives_ok { $m = $test->move_to_outgoing() } 'Move to outgoing lives';
    ok( !-e $test_target, 'is not in outgoing');
    is( $m, "Failed to move $test_source to $test_target" .
      ': No such file or directory', 'move is confirmed' );
    ok( -e $test_source, 'still in analysis' );

    make_path( $outgoing_dir );
    ok( -e $outgoing_dir, 'outgoing directory exists' );
    lives_ok { $m = $test->move_to_outgoing() } 'Move to outgoing lives';
    ok( -e $test_target, 'is in outgoing' );
    is( $m, "Moved $test_source to $test_target", 'move is confirmed' );
    ok( !-e $test_source, 'gone from analysis' );
    throws_ok { $test->move_to_outgoing() } qr/already\ exists/msx,
              'Refuse to overwrite an existing directory';

    move( $test_target, $test_source ); # Put things back as they were.
    my $flag = $tmpdir . '/IL12/analysis/100721_IL12_05222/npg_do_not_move';
    mkdir $flag;
    my $expected = $test_source . ' flagged not to be moved to outgoing';
    lives_ok { $m = $test->move_to_outgoing() } 'Move to outgoing lives';
    ok( !-e $test_target, 'not in outgoing' );
    is( $m, $expected, 'not moved since the runfolder has a flag');

    rmdir $flag;
    $flag = $tmpdir . '/IL12/analysis/100721_IL12_05222/npgdonotmove';
    mkdir $flag;
    lives_ok { $m = $test->move_to_outgoing() } 'Move to outgoing lives';
    ok( !-e $test_target, 'not in outgoing' );
    is( $m, $expected, 'not moved since the runfolder has a flag');
}

{
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $test_source  = $tmpdir . '/IL12/incoming/100721_IL12_05222';
    my $analysis_dir = $tmpdir . '/IL12/analysis';
    my $test_target  = $analysis_dir . '/100721_IL12_05222';
    make_path $test_source;
    make_path( $analysis_dir );

    $schema->resultset('Run')->find(5222)->update_run_status('run pending');
    my $test = Monitor::RunFolder::Staging->new( runfolder_path => $test_source,
                                                 status_update => 0,
                                                 npg_tracking_schema        => $schema, );

    lives_ok { $test->move_to_analysis() } 'Move to analysis';
    ok( !-e $test_source, 'runfolder is gone from incoming' );
    ok(  -e $test_target, 'runfolder is present in analysis' );
    is( $test->current_run_status_description(), 'run pending',
          'run status is unchanged' );
}

{
    my $tmpdir = tempdir( CLEANUP => 1 );
    system('cp',  '-rp', $MOCK_STAGING . '/IL5/incoming/100621_IL5_01204', $tmpdir);
    my $mock_path = $tmpdir . '/100621_IL5_01204';

    my $test = Monitor::RunFolder::Staging->new(runfolder_path      => $mock_path,
                                                npg_tracking_schema => $schema );

    find( sub { utime time, time, $_ }, $mock_path );

    my $future_time = time + 1_000_000;
    utime $future_time, $future_time, "$mock_path/Run.completed";

    my ( $size, $date ) = $test->monitor_stats($mock_path);

    is( $date, $future_time, 'Find latest modification time' );

    # Seems a little fragile (and unnecessary) to insist on an exact match.
    ok( $size > 1000, 'Find file size sum' );
}

{
    my $test = Monitor::RunFolder::Staging->new( runfolder_path => '/nfs/sf25/ILorHSany_sf25/outgoing/110712_HS8_06541_B_B0A6DABXX');
    is($test->_get_folder_path_glob, '/{export,nfs}/sf25/ILorHSany_sf25/*/', 'glob for /nfs/sf25 outgoing');
    $test = Monitor::RunFolder::Staging->new( runfolder_path => '/export/sf25/ILorHSany_sf25/incoming/110712_HS8_06541_B_B0A6DABXX');
    is($test->_get_folder_path_glob, '/{export,nfs}/sf25/ILorHSany_sf25/*/', 'glob for /export/sf25 incoming');
}

{
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
}

1;
