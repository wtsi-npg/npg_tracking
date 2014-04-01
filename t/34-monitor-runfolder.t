use strict;
use warnings;

use Carp;
use English qw(-no_match_vars);
use File::Copy;

use Test::More tests => 26;
use Test::Exception::LessClever;
use t::dbic_util;

use Readonly;

Readonly::Scalar my $MOCK_STAGING => 't/data/gaii/staging';


use_ok('Monitor::RunFolder');

my $schema = t::dbic_util->new->test_schema();
my $test;
my $mock_path = $MOCK_STAGING . '/IL12/incoming/100721_IL12_05222';

lives_ok {
            $test = Monitor::RunFolder->new( runfolder_path => $mock_path,
                                             _schema        => $schema, )
         }
         'Object creation ok';


{
    is( $test->run_folder(), '100721_IL12_05222',
        'Run folder attribute correct' );

    isa_ok( $test->run_db_row(), 'npg_tracking::Schema::Result::Run',
            'Object returned by run_db_row method' );

    is( $test->current_run_status_description(), 'analysis pending',
        'Retrieve current run status' );

    isa_ok( $test->file_obj(), 'Monitor::SRS::File',
            'Object returned by file_obj method' );

    # Test Monitor::Roles::Username
    is( $test->username(), 'pipeline',
        'Retrieve default username for updates' );
}


{
    $mock_path = $MOCK_STAGING . '/IL3/skip_this_one/090810_IL12_32890';
    $test = Monitor::RunFolder->new( runfolder_path => $mock_path,
                                     _schema        => $schema, );

    throws_ok { $test->run_db_row() }
              qr/Problem retrieving record for id_run => 32890/ms,
              'run_db_row croaks when the run isn\'t in the db';

    throws_ok { $test->current_run_status_description() }
              qr/Error getting current run status for run 32890/ms,
              'current_run_status_description croaks when the db has no current run';
}


{
    $mock_path = $MOCK_STAGING . '/IL4/incoming/101026_IL4_0095';
    $test = Monitor::RunFolder->new( runfolder_path => $mock_path,
                                     _schema        => $schema, );

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

    is( $test->run_db_row->actual_cycle_count(), 5, '  Cycle count updated' );

    lives_ok { $test->check_cycle_count( 43, 1 ) }
             '  Move run from \'in progress\' to \'complete\'';

    is( $test->current_run_status_description(), 'run complete',
        '  Run status updated' );

    is( $test->run_db_row->actual_cycle_count(), 43,
        '  Cycle count updated' );
}


{
    $mock_path = $MOCK_STAGING . '/IL4/incoming/101026_IL4_0095';
    $test = Monitor::RunFolder->new( runfolder_path => $mock_path,
                                     _schema        => $schema, );


    throws_ok { $test->read_long_info() } qr{No recipe file found}ms, 
              'Croak if no recipe file is found';    


    $mock_path = $MOCK_STAGING . '/IL12/incoming/100721_IL12_05222';
    $test = Monitor::RunFolder->new( runfolder_path => $mock_path,
                                     _schema        => $schema, );

    move( "$mock_path/Data", "$mock_path/_Data" ) or croak "Error $OS_ERROR";
    lives_ok { $test->read_long_info(0) } 'Call read_long_info method without error';
    move( "$mock_path/_Data", "$mock_path/Data" ) or croak "Error $OS_ERROR";

    is( $test->run_db_row->is_tag_set('single_read'), 1,
        '  \'single_read\' tag is set on this run' );
    is( $test->run_db_row->is_tag_set('multiplex'), 0,
        '  \'multiplex\' tag is not set on this run' );

    is( $test->run_db_row->is_tag_set('rta'), 0,
        '  \'rta\' tag is not set on this run' );


    $mock_path = $MOCK_STAGING . '/IL3/incoming/100622_IL3_01234';
    $test = Monitor::RunFolder->new( runfolder_path => $mock_path,
                                     _schema        => $schema, );
    $test->read_long_info(1);

    is( $test->run_db_row->is_tag_set('paired_read'), 1,
        '  \'paired_read\' tag is set on that run' );
    is( $test->run_db_row->is_tag_set('multiplex'), 1,
        '  \'multiplex\' tag is set on that run' );
    is( $test->run_db_row->is_tag_set('rta'), 1,
        '  \'rta\' tag is set on that run' );

}

1;
