#########
# Author:        jo3
# Created:       2010-06-15
#
use strict;
use warnings;

use Carp;
use English qw(-no_match_vars);
use File::Copy;
use File::Find;
use File::Temp qw(tempdir);

use Test::More tests => 47;
use Test::Exception::LessClever;
use Test::Warn;
use Test::Deep;
use IPC::System::Simple; #needed for Fatalised/autodying system()
use autodie qw(:all);

use t::dbic_util;

use Readonly;

Readonly::Scalar my $MOCK_STAGING => 't/data/gaii/staging';


use_ok('Monitor::RunFolder::Staging');

my $schema = t::dbic_util->new->test_schema();

{
    my $test;
    my $mock_path = $MOCK_STAGING . '/IL4/incoming/101026_IL4_0095';

    lives_ok {
           $test = Monitor::RunFolder::Staging->new(
                    runfolder_path => $mock_path,
                    _schema        => $schema, )
         }
         'Object creation ok';
    is($test->rta_complete_wait, 600, 'default rta complete wait time');
}

{
    my $mock_path = $MOCK_STAGING . '/IL3/incoming/100622_IL3_01234';
    my $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              _schema        => $schema, );

    is( $test->_get_folder_path_glob, $MOCK_STAGING . '/IL3/*/',
        'internal glob correct' );
    lives_ok { $test->update_folder } 'update folder name and glob in DB';
    is( $test->run_db_row->folder_name(), '100622_IL3_01234',
        '  folder name updated' );
    is( $test->run_db_row->folder_path_glob(), $MOCK_STAGING . '/IL3/*/',
        '  folder path glob updated' );

    is( $test->cycle_lag(), 1, 'Mirroring is lagging' );

    $mock_path = $MOCK_STAGING . '/IL999/incoming/100622_IL3_01234';
    $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              _schema        => $schema, );

    is( $test->cycle_lag(), 0, 'Mirroring is not lagging' );
}

{
    my $mock_path = $MOCK_STAGING . '/IL3/incoming/100622_IL3_01234';
    my $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              _schema        => $schema, );

    is( $test->validate_run_complete(), 0,
        'Called validate_run_complete before Events.log is complete' );

    $mock_path = $MOCK_STAGING . '/IL5/incoming/100708_IL3_04999';
    $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              _schema        => $schema, );
    is( $test->validate_run_complete(), 1,
        '\'run complete\' status is valid' );
}


{
    my $mock_path = $MOCK_STAGING . '/IL5/incoming/100621_IL5_01204';
    my $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              _schema        => $schema, );
    lives_ok { $test->mirroring_complete() }
             'Don\'t croak if the Events.log file is missing';


    $mock_path = $MOCK_STAGING . '/IL3/incoming/100622_IL3_01234';
    $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              _schema        => $schema, );

    is( $test->mirroring_complete(), 0, 'Mirroring is not complete' );


    $mock_path = $MOCK_STAGING . '/IL5/incoming/100708_IL3_04999';
    $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              _schema        => $schema, );

    is( $test->mirroring_complete(), 1, 'Mirroring is complete' );
}


{
    my $tmpdir = tempdir( CLEANUP => 1 );
 
    system('cp',  '-rp', $MOCK_STAGING . '/ILorHSany_sf20/incoming/100914_HS3_05281_A_205MBABXX', $tmpdir);
    sleep 15;
 
    my $mock_path = $tmpdir . '/100914_HS3_05281_A_205MBABXX';

    my $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              _schema        => $schema,
                                              rta_complete_wait => 15);

    rename "$mock_path/RTAComplete.txt", "$mock_path/RTA_renamed_Complete.txt";

    ok( !$test->mirroring_complete(),
        'Mirroring is not complete' );

    rename "$mock_path/RTA_renamed_Complete.txt", "$mock_path/RTAComplete.txt";

    ok( $test->mirroring_complete(),
        'Mirroring is complete' );
}


{
    my $mock_path = $MOCK_STAGING . '/IL12/incoming/100721_IL12_05222';
    my $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              _schema        => $schema, );

    warning_like { $test->check_tiles() }
                 { carped => qr/Missing[ ]lane[(]s[)]/msx },
                 'Report missing lanes';


    $mock_path = $MOCK_STAGING . '/IL3/incoming/100622_IL3_01234';
    $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              _schema        => $schema, );

    warning_like { $test->check_tiles() }
                 { carped => qr/Missing[ ]cycle[(]s[)]/msx },
                 'Report missing cycles';


    $mock_path = $MOCK_STAGING . '/IL5/incoming/100621_IL5_01204';
    $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              _schema        => $schema, );

    warning_like { $test->check_tiles() }
                 { carped => qr/Missing[ ]tile[(]s[)]/msx },
                 'Report missing tiles';


    $mock_path = $MOCK_STAGING . '/IL5/incoming/100708_IL3_04999';
    $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              _schema        => $schema, );

    lives_ok { $test->check_tiles() } 'All cif files present';
}


{
    my $mock_path = $MOCK_STAGING . '/IL5/incoming/100708_IL3_04999';
    my $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              _schema        => $schema, );


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
    my $mock_path = $MOCK_STAGING . '/IL3/skip_this_one/090810_IL12_3289';
    my $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              _schema        => $schema, );

    throws_ok { $test->move_to_analysis() }
              qr/$mock_path[ ]already[ ]exists/msx,
              'Refuse to overwrite an existing directory';

    my $test_source = $MOCK_STAGING . '/IL12/incoming/100721_IL12_05222';
    my $test_target = $MOCK_STAGING . '/IL12/analysis/100721_IL12_05222';

    # If a test fails it may leave the test data files in a broken state.
    ok(  -e $test_source, 'No corruption from previous test failures (1/3)' );
    ok( !-e $test_target, 'No corruption from previous test failures (2/3)' );

    isnt( $test->current_run_status_description(), 'analysis pending',
          'No corruption from previous test failures (3/3)' );

    package Monitor::RunFolder::Staging;
    use subs 'system';

    package main;
    my $fail = 1;
    my @args;

    *Monitor::RunFolder::Staging::system = sub {
        @args = @_;
        return $fail;
    };


    $test = Monitor::RunFolder::Staging->new( runfolder_path => $test_source,
                                              _schema        => $schema, );

    lives_ok { $test->move_to_analysis() } 'Move to analysis';

    ok( !-e $test_source, 'Run folder is gone from incoming' );
    ok(  -e $test_target, 'Run folder is present in analysis' );

    is( $test->current_run_status_description(), 'analysis pending',
          'Current run status is \'analysis pending\'' );

    # Put things back as they were.
    move( $test_target, $test_source );

    lives_ok { $test->move_to_analysis() } 
             'No error if analysis directory already exists...';
  
    ok( !-e $test_source, '   ...gone from incoming again' );
    ok(  -e $test_target, '   ...present in analysis again' );

    is( $test->current_run_status_description(), 'analysis pending',
          '   ...current run status unaffected' );

    move( $test_target, $test_source );
    $test_target =~ s{/analysis/.+}{/analysis}msx;

    rmdir $test_target;
}


{
    my $tmpdir = tempdir( CLEANUP => 1 );
    system('cp',  '-rp', $MOCK_STAGING . '/IL5/incoming/100621_IL5_01204', $tmpdir);
    my $mock_path = $tmpdir . '/100621_IL5_01204';

    my $test = Monitor::RunFolder::Staging->new( runfolder_path => $mock_path,
                                              _schema        => $schema, );

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

1;
