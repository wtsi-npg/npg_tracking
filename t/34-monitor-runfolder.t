use strict;
use warnings;
use English qw(-no_match_vars);
use File::Copy;
use Test::More tests => 29;
use Test::Exception;
use Test::Warn;
use File::Temp qw/ tempdir /;
use File::Path qw/ make_path /;

use t::dbic_util;

my $MOCK_STAGING = 't/data/gaii/staging';

use_ok('Monitor::RunFolder');

my $schema = t::dbic_util->new->test_schema();
my $test;
my $mock_path = $MOCK_STAGING . '/IL12/incoming/100721_IL12_05222';

lives_ok {
            $test = Monitor::RunFolder->new( runfolder_path       => $mock_path,
                                             npg_tracking_schema  => $schema, )
         }
         'Object creation ok';


{
    is( $test->run_folder(), '100721_IL12_05222',
        'Run folder attribute correct' );

    isa_ok( $test->tracking_run(), 'npg_tracking::Schema::Result::Run',
            'Object returned by tracking_run method' );

    is( $test->current_run_status_description(), 'analysis pending',
        'Retrieve current run status' );

    isa_ok( $test->file_obj(), 'Monitor::SRS::File',
            'Object returned by file_obj method' );

    # Test Monitor::Roles::Username
    is( $test->username(), 'pipeline',
        'Retrieve default username for updates' );
}


{
    $mock_path = $MOCK_STAGING . '/IL4/incoming/101026_IL4_0095';
    $test = Monitor::RunFolder->new( runfolder_path      => $mock_path,
                                     npg_tracking_schema => $schema, );

    is( $test->current_run_status_description(), 'run pending',
        ' test is ready' );

    throws_ok { $test->check_cycle_count() }
              qr{Latest cycle count not supplied}ms, 
              '  check_cycle_count requires latest cycle count argument';

    throws_ok { $test->check_cycle_count(5) }
              qr{Run complete Boolean not supplied}ms,
              '  check_cycle_count requires run complete argument';

    lives_ok { $test->check_cycle_count( 5, 0 ) }
             '  Move run from \'pending\' to \'in progress\'';

    is( $test->current_run_status_description(), 'run in progress',
        '  Run status updated' );

    is( $test->tracking_run->actual_cycle_count(), 5, '  Cycle count updated' );

    lives_ok { $test->check_cycle_count( 43, 1 ) }
             '  Move run from \'in progress\' to \'complete\'';

    is( $test->current_run_status_description(), 'run complete',
        '  Run status updated' );

    is( $test->tracking_run->actual_cycle_count(), 43,
        '  Cycle count updated' );
}


{
    $mock_path = $MOCK_STAGING . '/IL4/incoming/101026_IL4_0095';
    $test = Monitor::RunFolder->new( runfolder_path      => $mock_path,
                                     npg_tracking_schema => $schema, );


    throws_ok { $test->read_long_info() } qr{No recipe file found}ms, 
              'Croak if no recipe file is found';    


    $mock_path = $MOCK_STAGING . '/IL12/incoming/100721_IL12_05222';
    $test = Monitor::RunFolder->new( runfolder_path      => $mock_path,
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

    $mock_path = $MOCK_STAGING . '/IL3/incoming/100622_IL3_01234';
    $test = Monitor::RunFolder->new( runfolder_path      => $mock_path,
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
      <Read Number="1" NumCycles="100" IsIndexedRead="N" />
      <Read Number="2" NumCycles="8" IsIndexedRead="Y" />
      <Read Number="3" NumCycles="100" IsIndexedRead="N" />
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

    foreach my $i ((1 .. 8)) {
      $schema->resultset('RunLane')->create({
        id_run => 1234, position => $i, tile_count => 16, tracks => 2});
      
    }
    is ($test->tracking_run()->run_lanes->count, 8, 'run has eight lanes');

    # create RunInfo file
    open my $fh, '>', join(q[/], $rf, 'RunInfo.xml');
    print $fh $run_info;
    close $fh;

    $test = Monitor::RunFolder->new( runfolder_path      => $rf,
                                     npg_tracking_schema => $schema, );
    warnings_like { $test->read_long_info(1) } [
      qr/Deleted lane 3/, qr/Deleted lane 4/, qr/Deleted lane 5/,
      qr/Deleted lane 6/, qr/Deleted lane 7/, qr/Deleted lane 8/],
      'warnings about lane deletion';
      
    is ($test->lane_count, 2, 'two lanes listed in run info');
    is ($test->tracking_run()->run_lanes->count, 2, 'now run has two lanes');

    $test->read_long_info();
    is ($test->tracking_run()->run_lanes->count, 2, 'no change - run has two lanes');
}

1;
