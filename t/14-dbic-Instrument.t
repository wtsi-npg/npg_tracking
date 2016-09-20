use strict;
use warnings;
use Test::More tests => 54;
use Test::Deep;
use Test::Exception::LessClever;
use DateTime;
use DateTime::Duration;

use t::dbic_util;

use_ok('npg_tracking::Schema::Result::Instrument');


my $schema = t::dbic_util->new->test_schema();
my $test;
my $test_instrument_id = 6;

{
    lives_ok {
        $test = $schema->resultset('Instrument')->find
                        ( { id_instrument => $test_instrument_id } )
    } 'Create test object';

    isa_ok( $test, 'npg_tracking::Schema::Result::Instrument', 'Correct class' );
    is( $test->current_instrument_status(), 'wash required',
        'new instrument status returned' );

    my $id = $schema->resultset('InstrumentStatusDict')
        ->find({description => 'wash performed',})->id_instrument_status_dict;
    my $wash_interval = $test->instrument_format->days_between_washes;
    if (!$wash_interval) {
        die 'No wash interval';
    }
    $schema->resultset('InstrumentStatus')->create(
        {id_instrument => $test_instrument_id,
         id_instrument_status_dict => $id,
         id_user => 1,
         iscurrent => 0,
         date => DateTime->now()
             ->subtract_duration(DateTime::Duration->new(days=>$wash_interval+4)),
        });
    throws_ok {$test->update_instrument_status('down', 'joe_engineer', 'instrument is down')}
        qr/Instrument status \"down\" is not current/,
        'error attempting to changed status to down (not current)';
    lives_ok {$test->update_instrument_status('planned repair', 'joe_engineer', 'instrument is down')}
        'status changed to planned repair';
    ok(!$test->set_status_wash_requied_if_needed(), 'wash not needed');
    is($test->current_instrument_status, 'planned repair', 'status has not changed');
}


# Status updates.
{
    lives_ok { $test->update_instrument_status( 'planned repair', 'joe_loader' ) }
             'Set a status that is already current';

    my $instrument_status_rs = $schema->resultset('InstrumentStatus')->search(
        {
            id_instrument => $test_instrument_id,
            iscurrent     => 1,
        }
    );
    is( $instrument_status_rs->first->comment(), 'instrument is down', 'original comment' );

    lives_ok {
               $test->update_instrument_status(
                   'request approval', 'pipeline', 'to approve'
               )
             }
             'Set a new status';
    my $instrument_status = $schema->resultset('InstrumentStatus')->find(
        {
            id_instrument => $test_instrument_id,
            iscurrent     => 1,
        }
    );
    is( $instrument_status->comment(), 'automatic status update : to approve', 'pipeline comment' );
    is( $instrument_status->instrument_status_dict->description, 'request approval', 'new status is request approval');
    ok(!$test->set_status_wash_requied_if_needed(), 'wash not needed');
    is($test->current_instrument_status,  'request approval', 'status has not changed');

    $instrument_status_rs = $schema->resultset('InstrumentStatus')->search(
        {
            id_instrument => $test_instrument_id,
            iscurrent     => 1,
        }
    );
    is( $instrument_status_rs->count(), 1, 'Only one row is current' );


    lives_ok {
               $test->update_instrument_status(
                    'up', 'pipeline'
               )
             }
             'Status set by automatic pipeline';

    $instrument_status_rs = $schema->resultset('InstrumentStatus')->search(
        {
            id_instrument => $test_instrument_id,
            iscurrent     => 1,
        }
    );
    is( $instrument_status_rs->first->comment(), 'automatic status update',
        'Comment reflects automatic status update without custom comment' );

    $instrument_status_rs = $schema->resultset('InstrumentStatus')->search(
        {
            id_instrument => $test_instrument_id,
            iscurrent     => 0,
        }
    );
    is( $instrument_status_rs->count(), 4, '4 non-current rows' );
    ok($test->set_status_wash_requied_if_needed(), 'wash needed, wash required status has been set');
    is($test->current_instrument_status, 'wash required', 'status changed to wash required');
    ok(!$test->set_status_wash_requied_if_needed(), 'wash does not need to be set');
}

{
    lives_ok {
                $test = $schema->resultset('Instrument')->find
                            ( { id_instrument => 67 } )
             }
             'Create a new test object - HiSeq, two active runs';

    my $active_rs = $test->current_runs();
    is( $active_rs->count(), 2, 'Find two active runs' );
    cmp_bag( [ $active_rs->get_column('id_run')->all() ], [ 5329, 5330 ],
             'Match the run ids' );


    lives_ok {
                $test = $schema->resultset('Instrument')->find
                            ( { id_instrument => 68 } )
             }
             'Create a new test object - HiSeq, one active run';

    $active_rs = $test->current_runs();
    is( $active_rs->count(), 1, 'Find one active run' );
    cmp_bag( [ $active_rs->get_column('id_run')->all() ], [ 4329 ],
             'Match the run id' );


    lives_ok {
                $test = $schema->resultset('Instrument')->find
                            ( { id_instrument => 15 } )
             }
             'Create a new test object - GAII, one active run';

    $active_rs = $test->current_runs();
    is( $active_rs->count(), 1, 'Find one active run' );
    ok( !$test->is_idle, 'instrument is not idle');
    cmp_bag( [ $active_rs->get_column('id_run')->all() ], [ 3 ],
             'Match the run id' );

    my $run = $schema->resultset('Run')->find({
            id_run     => 3,
        }
    );
    is($run->id_instrument, 15, 'found this run');
    $run->update_run_status('run complete', 'pipeline');
    ok( !$test->is_idle, 'instrument is not idle for run complete');
    lives_ok {
               $test->update_instrument_status(
                    'planned service', 'pipeline'
               )
             }
             'instrument status changed to planned routine maintenance';
    $run->update_run_status('run mirrored', 'pipeline');
    ok( $test->is_idle, 'instrument is idle for run mirrored');
    is( $test->current_instrument_status, 'down for service',
      'status changed automatically to "down for service"');

    $test->update_instrument_status('request approval', 'pipeline');
    $test->update_instrument_status('up', 'pipeline');
    ok($test->set_status_wash_requied_if_needed(), 'wash status has been set');
    is($test->current_instrument_status, 'wash required', 'status changed to wash required');

    lives_ok {
                $test = $schema->resultset('Instrument')->find
                            ( { id_instrument => 3 } )
             }
             'Create a new test object - GAII, one run on hold';

    $active_rs = $test->current_runs();
    is( $active_rs->count(), 1, 'One current run' );
    ok( !$test->is_idle, 'instrument is not idle');

    $run = $schema->resultset('Run')->find({
            id_run     => 1,
        }
    );
    is($run->id_instrument, 3, 'found this run');
    $run->update_run_status('run cancelled', 'pipeline');
    is( $test->current_runs()->count(), 0, 'no current runs' );
    ok( $test->is_idle, 'instrument is idle');
}

{
    my $i;
    my $name = 'new name';
    lives_ok { $i = $schema->resultset('Instrument')->create({
            id_instrument => 100,
            id_instrument_format => 10,
            name => $name,
            external_name => 'external',
            serial => '12345',
            iscurrent => 1,       
        })
    } 'no error creating a new HiSeq instrument';
    is($i->name, $name, 'new instrument name is correct');
    is( $i->instrument_format->model, 'HiSeq', 'is HiSeq instrument');
    is( $i->current_instrument_status, 'wash required', 'initial instrument status is set');

    throws_ok { $i = $schema->resultset('Instrument')->create({
            id_instrument => 101,
            id_instrument_format => 20,
            name => $name . '1',
            external_name => 'external',
            serial => '12345',
            iscurrent => 1,       
        })
    } qr/call method \"model\" on an undefined value/, 'error creating a new instrument with unknown format';

    lives_ok { $i = $schema->resultset('Instrument')->create({
            id_instrument => 102,
            id_instrument_format => 7,
            name => $name . q[2],
            external_name => 'external',
            serial => '12345',
            iscurrent => 1,       
        })
    } 'no error creating a new cbot instrument';
    is($i->name, $name.q[2], 'new instrument name is correct');
    is( $i->instrument_format->model, 'cBot', 'is cBot instrument');
    is( $i->current_instrument_status, undef, 'no initial instrument status');
}

1;
