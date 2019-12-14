use strict;
use warnings;
use English qw(-no_match_vars);
use File::Copy;
use Test::More tests => 32;
use Test::Exception;
use Test::Warn;
use File::Temp qw/ tempdir /;
use File::Path qw/ make_path /;
use File::Slurp;

use t::dbic_util;

use_ok('Monitor::RunFolder');

my $schema = t::dbic_util->new->test_schema();
my $MOCK_STAGING = 't/data/gaii/staging';
my $dir4rf = tempdir( CLEANUP => 1 );

{
    my $mock_path = $MOCK_STAGING . '/IL12/incoming/100721_IL12_05222';
    my $test;
    lives_ok {
        $test = Monitor::RunFolder->new( runfolder_path       => $mock_path,
                                         npg_tracking_schema  => $schema, )
    } 'Object creation ok';
    isa_ok( $test, 'Monitor::RunFolder');

    is( $test->run_folder(), '100721_IL12_05222',
        'Run folder attribute correct' );

    isa_ok( $test->tracking_run(), 'npg_tracking::Schema::Result::Run',
            'Object returned by tracking_run method' );

    is( $test->tracking_run()->current_run_status_description(), 'analysis pending',
        'Retrieve current run status' );

    # Test Monitor::Roles::Username
    is( $test->username(), 'pipeline',
        'Retrieve default username for updates' );
}

{
    my $mock_path = $MOCK_STAGING . '/IL4/incoming/101026_IL4_0095';
    my $test = Monitor::RunFolder->new( runfolder_path      => $mock_path,
                                        npg_tracking_schema => $schema, );

    is( $test->tracking_run()->current_run_status_description(), 'run pending',
        ' test is ready' );

    throws_ok { $test->check_cycle_count() }
              qr{Latest cycle count not supplied}ms, 
              '  check_cycle_count requires latest cycle count argument';

    throws_ok { $test->check_cycle_count(5) }
              qr{Run complete Boolean not supplied}ms,
              '  check_cycle_count requires run complete argument';

    lives_ok { $test->check_cycle_count( 5, 0 ) }
             '  Move run from \'pending\' to \'in progress\'';

    is( $test->tracking_run()->current_run_status_description(), 'run in progress',
        '  Run status updated' );

    is( $test->tracking_run->actual_cycle_count(), 5, '  Cycle count updated' );

    lives_ok { $test->check_cycle_count( 43, 1 ) }
             '  Move run from \'in progress\' to \'complete\'';

    is( $test->tracking_run()->current_run_status_description(), 'run complete',
        '  Run status updated' );

    is( $test->tracking_run->actual_cycle_count(), 43,
        '  Cycle count updated' );
}

{
    my $mock_path = $MOCK_STAGING . '/IL4/incoming/101026_IL4_0095';
    my $test = Monitor::RunFolder->new( runfolder_path      => $mock_path,
                                        npg_tracking_schema => $schema, );


    throws_ok { $test->read_long_info() } qr{File not found}ms,
              'Croak if no recipe file is found';

    my $basedir = tempdir( CLEANUP => 1 );
    my $fs_run_folder = qq[$basedir/IL12/incoming/100721_IL12_05222];
    make_path($fs_run_folder);
    $mock_path = $MOCK_STAGING . '/IL12/incoming/100721_IL12_05222';
    system('cp',  '-rp', $mock_path, qq[$basedir/IL3/incoming]);
    my $fh;
    my $runinfofile = qq[$fs_run_folder/RunInfo.xml];
    open($fh, '>', $runinfofile) or die "Could not open file '$runinfofile' $!";
    print $fh <<"ENDXML";
<?xml version="1.0"?>
  <RunInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="3">
  <Run>
    <Reads>
    <Read Number="1" NumCycles="76" IsIndexedRead="N" />
    </Reads>
    <FlowcellLayout LaneCount="8" SurfaceCount="2" SwathCount="1" TileCount="60">
    </FlowcellLayout>
  </Run>
  </RunInfo>
ENDXML
    close $fh;

    $test = Monitor::RunFolder->new( runfolder_path      => $fs_run_folder,
                                     npg_tracking_schema => $schema, );

    move( "$mock_path/Data", "$mock_path/_Data" ) or die "Error $OS_ERROR";
    lives_ok { $test->read_long_info() } 'Call read_long_info method without error';
    move( "$mock_path/_Data", "$mock_path/Data" ) or die "Error $OS_ERROR";

    is( $test->tracking_run()->is_tag_set('single_read'), 1,
        '  \'single_read\' tag is set on this run' );
    is( $test->tracking_run()->is_tag_set('multiplex'), 0,
        '  \'multiplex\' tag is not set on this run' );

    is( $test->tracking_run()->is_tag_set('rta'), 1,
        '  \'rta\' tag is set' );

    my $basedir2 = tempdir( CLEANUP => 1 );
    my $fs_run_folder2 = qq[$basedir2/IL3/incoming/100622_IL3_01234];
    make_path($fs_run_folder2);
    my $mock_path2 = $MOCK_STAGING . '/IL3/incoming/100622_IL3_01234';
    system('cp',  '-rp', $mock_path2, qq[$basedir2/IL3/incoming]);
    my $fh2;
    my $runinfofile2 = qq[$fs_run_folder2/RunInfo.xml];
    open($fh2, '>', $runinfofile2) or die "Could not open file '$runinfofile2' $!";
    print $fh2 <<"ENDXML";
<?xml version="1.0"?>
  <RunInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="3">
  <Run>
    <Reads>
    <Read Number="1" NumCycles="35" IsIndexedRead="N" />
    <Read Number="2" NumCycles="6" IsIndexedRead="Y" />
    <Read Number="3" NumCycles="35" IsIndexedRead="N" />
    </Reads>
    <FlowcellLayout LaneCount="8" SurfaceCount="2" SwathCount="1" TileCount="60">
    </FlowcellLayout>
  </Run>
  </RunInfo>
ENDXML
    close $fh2;

    $test = Monitor::RunFolder->new( runfolder_path      => $fs_run_folder2,
                                     npg_tracking_schema => $schema, );
    $test->read_long_info();

    is( $test->tracking_run()->is_tag_set('paired_read'), 1,
        '  \'paired_read\' tag is set on that run' );
    is( $test->tracking_run()->is_tag_set('multiplex'), 1,
        '  \'multiplex\' tag is set on that run' );
    is( $test->tracking_run()->is_tag_set('rta'), 1,
        '  \'rta\' tag is set on that run' );
}

{
    my $run_info =
q{<?xml version="1.0"?>
<RunInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="2">
  <Run Id="150606_HS31_16475_B_HCYVGADXX" Number="469">
    <Flowcell>HCYVGADXX</Flowcell>
    <Instrument>D00241</Instrument>
    <Date>150606</Date>
    <Reads>
      <Read Number="1" NumCycles="35" IsIndexedRead="N" />
      <Read Number="2" NumCycles="6" IsIndexedRead="Y" />
      <Read Number="3" NumCycles="35" IsIndexedRead="N" />
    </Reads>
    <FlowcellLayout LaneCount="2" SurfaceCount="2" SwathCount="2" TileCount="16" />
    <AlignToPhiX>
      <Lane>1</Lane>
      <Lane>2</Lane>
    </AlignToPhiX>
  </Run>
</RunInfo>};

    
    my $root = tempdir( CLEANUP => 1 );
    my $rf = join q[/], $root, 'ILorHSany_sf50/incoming/150606_HS31_01234_B_HCYVGADXX';
    make_path $rf;

    my $test = Monitor::RunFolder->new( runfolder_path      => $rf,
                                        npg_tracking_schema => $schema );
    foreach my $i ((1 .. 8)) {
      $schema->resultset('RunLane')->create({
        id_run => 1234, position => $i, tile_count => 16, tracks => 2});
      
    }
    is ($test->tracking_run()->run_lanes->count, 8, 'run has eight lanes');

    # create RunInfo file
    open my $fh, '>', join(q[/], $rf, 'RunInfo.xml');
    print $fh $run_info;
    close $fh;

    warnings_like { $test->read_long_info(1) } [
      qr/Deleted lane 3/, qr/Deleted lane 4/, qr/Deleted lane 5/,
      qr/Deleted lane 6/, qr/Deleted lane 7/, qr/Deleted lane 8/],
      'warnings about lane deletion';
      
    is ($test->lane_count, 2, 'two lanes listed in run info');
    is ($test->tracking_run()->run_lanes->count, 2, 'now run has two lanes');

    $test->read_long_info();
    is ($test->tracking_run()->run_lanes->count, 2, 'no change - run has two lanes');
}

subtest 'workflow and instrument side - NovaSeq run' => sub {
    plan tests => 16;
    
    # Standard flow
    my $rfp = join q[/], $dir4rf, q[rf1];
    mkdir $rfp;
    copy 't/data/run_info/runInfo.novaseq.xml', "$rfp/RunInfo.xml"
       or die 'Failed to copy a test file';
    copy 't/data/run_params/RunParameters.novaseq.xml', "$rfp/RunParameters.xml"
       or die 'Failed to copy a test file';

    my $run = $schema->resultset('Run')->find(26487);
    foreach my $t (qw/workflow_NovaSeqXp workflow_NovaSeqStandard fc_slotB fc_slotA/) {
        $run->unset_tag($t);
    }

    my $rf = Monitor::RunFolder->new(runfolder_path      => $rfp,
                                     id_run              => 26487,
                                     npg_tracking_schema => $schema);

    is ($rf->set_workflow_type(), 'NovaSeqStandard', 'standard wf type is set');
    ok ($run->is_tag_set('workflow_NovaSeqStandard'), 'standard flow tag is set');
    is ($rf->set_workflow_type(), undef, 'wf type is not set since it has not changed');
    ok ($run->is_tag_set('workflow_NovaSeqStandard'), 'standard flow tag is set');

    is ($rf->set_instrument_side(), 'B', 'side B is set');
    ok ($run->is_tag_set('fc_slotB'), 'side B tag set');
    is ($rf->set_instrument_side(), undef, 'side is not set since it has not changed');
    ok ($run->is_tag_set('fc_slotB'), 'side B tag set');

    # XP flow
    my $content = read_file('t/data/run_params/RunParameters.novaseq.xp.xml');
    $content =~ s/<Side>B</<Side>A</;
    write_file( "$rfp/RunParameters.xml", $content);

    $rf = Monitor::RunFolder->new(runfolder_path      => $rfp,
                                  id_run              => 26487,
                                  npg_tracking_schema => $schema);

    is ($rf->set_workflow_type(), 'NovaSeqXp', 'xp wf type is set - a fix');
    ok ($run->is_tag_set('workflow_NovaSeqXp'), 'xp flow tag is set');
    is ($rf->set_workflow_type(), undef, 'wf type is not set since it has not changed');
    ok ($run->is_tag_set('workflow_NovaSeqXp'), 'xp flow tag is set');

    is ($rf->set_instrument_side(), 'A', 'side A is set - a fix');
    ok ($run->is_tag_set('fc_slotA'), 'side A tag set');
    is ($rf->set_instrument_side(), undef, 'side is not set since it has not changed');
    ok ($run->is_tag_set('fc_slotA'), 'side A tag set');    
};

subtest 'workflow and instrument side - HiSeq run' => sub {
    plan tests => 11;

    my $rfp = join q[/], $dir4rf, q[rf2];
    mkdir $rfp;
    copy 't/data/run_info/runInfo.hiseq.xml', "$rfp/RunInfo.xml"
       or die 'Failed to copy a test file';
    copy 't/data/run_params/runParameters.hiseq.xml', "$rfp/runParameters.xml"
       or die 'Failed to copy a test file';

    my $run = $schema->resultset('Run')->find(6670);
    foreach my $t (qw/workflow_NovaSeqXp workflow_NovaSeqStandard fc_slotB fc_slotA/) {
        $run->unset_tag($t);
    }

    my $rf = Monitor::RunFolder->new(runfolder_path      => $rfp,
                                     id_run              => 6670,
                                     npg_tracking_schema => $schema);

    is ($rf->set_workflow_type(), undef, 'wf type is not set since it is not defined in long info');
    ok (!$run->is_tag_set('workflow_NovaSeqStandard'), 'standard flow tag is not set');
    ok (!$run->is_tag_set('workflow_NovaSeqXp'), 'xp flow tag is not set');

    is ($rf->set_instrument_side(), 'A', 'side A is set');
    ok ($run->is_tag_set('fc_slotA'), 'side A tag set');
    is ($rf->set_instrument_side(), undef, 'side is not set since it has not changed');
    ok ($run->is_tag_set('fc_slotA'), 'side A tag set');

    my $content = read_file('t/data/run_params/runParameters.hiseq.xml');
    $content =~ s/<FCPosition>A</<FCPosition>B</;
    write_file( "$rfp/runParameters.xml", $content);

    $rf = Monitor::RunFolder->new(runfolder_path      => $rfp,
                                  id_run              => 6670,
                                  npg_tracking_schema => $schema);

    is ($rf->set_instrument_side(), 'B', 'side B is set - a fix');
    ok ($run->is_tag_set('fc_slotB'), 'side B tag set');
    is ($rf->set_instrument_side(), undef, 'side is not set since it has not changed');
    ok ($run->is_tag_set('fc_slotB'), 'side B tag set');    
};

subtest 'workflow and instrument side - MiSeq run' => sub {
    plan tests => 6;

    my $rfp = join q[/], $dir4rf, q[rf3];
    mkdir $rfp;

    copy 't/data/run_info/runInfo.miseq.xml', "$rfp/RunInfo.xml"
       or die 'Failed to copy a test file';
    copy 't/data/run_params/runParameters.miseq.xml', "$rfp/runParameters.xml"
       or die 'Failed to copy a test file';

    my $run = $schema->resultset('Run')->find(7826);
    foreach my $t (qw/workflow_NovaSeqXp workflow_NovaSeqStandard fc_slotB fc_slotA/) {
        $run->unset_tag($t);
    }

    my $rf = Monitor::RunFolder->new(runfolder_path      => $rfp,
                                     id_run              => 7826,
                                     npg_tracking_schema => $schema);

    is ($rf->set_workflow_type(), undef, 'wf type is not set since it is not defined in long info');
    ok (!$run->is_tag_set('workflow_NovaSeqStandard'), 'standard flow tag is not set');
    ok (!$run->is_tag_set('workflow_NovaSeqXp'), 'xp flow tag is not set');
    is ($rf->set_instrument_side(), undef, 'side is not set since it is not defined in long_info');
    ok (!$run->is_tag_set('fc_slotB'), 'side B tag is not set');
    ok (!$run->is_tag_set('fc_slotA'), 'side A tag is not set'); 
};

1;
