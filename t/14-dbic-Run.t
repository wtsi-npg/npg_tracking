use strict;
use warnings;
use Test::More tests => 108;
use Test::Exception;
use t::dbic_util;

use_ok('npg_tracking::Schema::Result::Run');

my $schema = t::dbic_util->new->test_schema();
my $test;
my $test_run_id = 1;

lives_ok {$test = $schema->resultset('Run')->find( { id_run => $test_run_id } )}
    'Create test object';
isa_ok( $test, 'npg_tracking::Schema::Result::Run', 'Correct class' );

{
    my $event_type_rs = $test->_event_type_rs();
    my $user_rs       = $test->_user_rs();

    isa_ok( $event_type_rs, 'npg_tracking::Schema::Result::EventType',
            'Event type result set' );

    isa_ok( $user_rs, 'npg_tracking::Schema::Result::User',
            'User result set' );
}

{
    is( $test->current_run_status_description(), 'run complete',
        'Current run status returned' );
}

# Status updates.
{
    my $new;
    lives_ok { $new = $test->update_run_status( 'run complete', 'joe_loader' ) }
             'Set a status that is already current and older than the new one';
    is($new, undef, 'new row object is not returned');

    my $run_status = $schema->resultset('RunStatus')->search(
        { id_run    => $test_run_id, iscurrent => 1,})->first;

    my $test_date = $run_status->date();
    my $same_time = $test_date->clone();
    is( $test_date->datetime, '2007-06-05T10:16:55', 'current status date not changed' );
    is( $run_status->related_resultset('run_status_dict')->next->description,
      'run complete', 'current run status as expected');

    $test_date->subtract_duration(DateTime::Duration->new(seconds => 1));
    $new = $test->update_run_status( 'run complete', 'joe_loader', $test_date );
    isa_ok( $new, q{npg_tracking::Schema::Result::RunStatus}, 'new row created');
    ok( !$new->iscurrent, 'new status is not marked as current');
    is( $new->date()->datetime, '2007-06-05T10:16:54', 'new status has correct older date');

    $new = $test->update_run_status( 'run complete', 'joe_loader');
    ok(!$new, 'status is not updated'); 
    $run_status = $schema->resultset('RunStatus')->search(
        { id_run    => $test_run_id, iscurrent => 1,})->first;
    is( $run_status->date()->datetime, '2007-06-05T10:16:55',
      'current status date not changed' );

    $new = $test->update_run_status( 'analysis pending', 'joe_loader', $same_time);
    isa_ok( $new, q{npg_tracking::Schema::Result::RunStatus}, 'new row created');
    ok( $new->iscurrent, 'new status is marked as current');
    is( $new->date()->datetime, '2007-06-05T10:16:55', 'new status has correct date');
    is( $new->related_resultset('run_status_dict')->next->description,
      'analysis pending', 'new current run status description');

    my $before = $test->get_time_now();
    lives_ok { $new = $test->update_run_status( 'run stopped early', 'joe_loader' ) }
             'Set a new status';
    isa_ok ($new, q{npg_tracking::Schema::Result::RunStatus}, 'new row object returned');

    my $run_status_rs = $schema->resultset('RunStatus')->search(
        { id_run    => $test_run_id, iscurrent => 1,});
    is( $run_status_rs->first->id_run_status_dict(), 22, 'New run status' );
    isnt( $run_status_rs->first->date(), $test_date,
          'New entry is an update not a copy' );
    cmp_ok( $run_status_rs->first->date(), '>=', $before, 'Current date' );

    is( $run_status_rs->count(), 1, 'Only one row has \'iscurrent\' set' );

    my $same_date = $run_status_rs->first->date();
    $new = $test->update_run_status( 'data discarded', 'joe_loader', $same_date );
    isa_ok ($new, q{npg_tracking::Schema::Result::RunStatus}, 'new row object returned');
    is($new->iscurrent, 1, 'new row is current');
    is($new->date->datetime, $same_date->datetime, 'timestamp set as passed');
    is($test->current_run_status->run_status_dict->description, 'data discarded',
         'current status description as expected');

    my $old_date = $same_date->subtract_duration(DateTime::Duration->new(seconds => 1));
    $new = $test->update_run_status( 'run cancelled', 'joe_loader', $old_date );
    isa_ok ($new, q{npg_tracking::Schema::Result::RunStatus}, 'new row object returned');
    is($new->iscurrent, 0, 'new row is not current');
    is($new->date->datetime, $old_date->datetime, 'timestamp set as passed');
    is($test->current_run_status->run_status_dict->description, 'data discarded',
         'current status description as before the update');
    
    sleep 1;
    my $now = $test->get_time_now();
    $new = $test->update_run_status( 'analysis pending', 'joe_loader', $now );
    isa_ok ($new, q{npg_tracking::Schema::Result::RunStatus}, 'new row object returned');
    is($new->iscurrent, 1, 'new row is current');
    is($new->date->datetime, $now->datetime, 'timestamp set as passed');
    is($test->current_run_status->run_status_dict->description, 'analysis pending',
         'current status description as expected');
    is($test->current_run_status->user->username, 'joe_loader',
         'username as given');
    $new = $test->update_run_status( 'analysis in progress');
    isa_ok ($new, q{npg_tracking::Schema::Result::RunStatus}, 'new row object returned');
    is($new->iscurrent, 1, 'new row is current');
    is($test->current_run_status->user->username, 'pipeline',
         'pipeline user is set for this status');

    $new = $test->update_run_status( 'analysis pending', 'joe_loader', $now );
    ok(!$new, 'cannot create a duplicate (same description and timestamp)'); 
}

# Status events
{
    my $e_rs = $schema->resultset('Event');

    throws_ok { $test->run_status_event('joe_loader') }
              qr/No[ ]run_status[ ]id[ ]supplied/msx,
              'Croak without run status id';

    my $et_rs = $schema->resultset('EventType');
    my $et_query = { id_entity_type => 6, description => 'status change' };
    $et_rs->search($et_query)->delete();

    throws_ok { $test->run_status_event( 'joe_loader', 5 ) }
              qr/No[ ]matching[ ]event[ ]type[ ]found/msx,
              'Croak with unknown event type';

    my $ev;
    lives_ok { $ev = $e_rs->create({}); } 'Lives on event creation';
    is( $ev->notification_sent(), undef, 'Notification not sent' );

    $et_rs->create($et_query);
}

{
    my $rta_query         = { id_run => $test_run_id,
                              id_tag => 16 };
    my $paired_read_query = { id_run => $test_run_id,
                              id_tag => 17 };
    my $single_read_query = { id_run => $test_run_id,
                              id_tag => 18 };
    my $multiplex_query   = { id_run => $test_run_id,
                              id_tag => 20 };

    my $paired_tag_rs = $schema->resultset('TagRun')->search($paired_read_query);
    my $single_tag_rs = $schema->resultset('TagRun')->search($single_read_query);

    # Make sure we start off in the right place. (This is a test of the test.)
    is( $paired_tag_rs->count(), 1, 'Start off with one \'paired\' tag' );
    is( $single_tag_rs->count(), 0, 'Start off with no \'single\' tags' );

    # Test is_tag_set method while we're here.
    is( $test->is_tag_set('paired_read'), 1, 'Predicate test on a set tag' );
    is( $test->is_tag_set('single_read'), 0, 'Predicate test on an unset tag' );

    # Start over.
    my $tg_rs = $schema->resultset('TagRun');

    throws_ok { $test->set_tag(3) } qr/Tag is required/,
        'error on missing tag argument';
    throws_ok { $test->set_tag(3, 'some_tag') }
        qr/Cannot set unknown tag \'some_tag\'/,
        'error on setting a non-esisting tag';
    throws_ok { $test->set_tag('use_unknown', 'rta') }
        qr/Invalid identifier: use_unknown/,
        'error on using an invalid user name';

    my $tagrun_rs = $tg_rs->search($rta_query);
    is( $tagrun_rs->count(), 0, 'Make sure rta tag is not already set' );
    is( $test->set_tag( 3, 'rta' ), 1, 'Use general method to set rta tag');
    $tagrun_rs = $tg_rs->search($rta_query);
    is( $tagrun_rs->count(), 1, 'rta tag has been set' );

    $tagrun_rs = $tg_rs->search($single_read_query);
    is( $tagrun_rs->count(), 0, 'single_read tag is not already set' );
    is( $test->set_tag( 3, 'single_read' ), 1, 'single_read tag is set');
    $tagrun_rs = $tg_rs->search($single_read_query);
    is( $tagrun_rs->count(), 1, 'single_read tag has been set' );
    $tagrun_rs = $tg_rs->search($paired_read_query);
    is( $tagrun_rs->count(), 0, 'paired_read tag has been removed' );

    lives_ok { $test->unset_tag('rta' ) } 'Use general method to unset tag';
    $tagrun_rs = $tg_rs->search($rta_query);
    is( $tagrun_rs->count(), 0, 'rta tag has been removed' );

    lives_ok { $test->unset_tag('single_read' ) } 'Same unset method for paired tags';
    $tagrun_rs = $tg_rs->search($single_read_query);
    is( $tagrun_rs->count(), 0, 'single_read tag has been removed' );
    $tagrun_rs = $tg_rs->search($paired_read_query);
    is( $tagrun_rs->count(), 0, 'paired_read tag has not been set' );

    is( $test->set_tag( 3, 'paired_read' ), 1, 'paired read tag set');
    is( $test->set_tag( 3, 'paired_read' ), 0, 'paired read tag not set again');
    
    lives_ok { $test->unset_tag('some_tag') }
        'no error unsetting non-existing tag';
}

# Tests for updating instrument status
{
    my $one_of_two_active =
        $schema->resultset('Run')->find( { id_run => 5329 } );
    my $two_of_two_active =
        $schema->resultset('Run')->find( { id_run => 5330 } );
    my $active_one_of_two =
        $schema->resultset('Run')->find( { id_run => 4329 } );
    my $inactive_one_of_two =
        $schema->resultset('Run')->find( { id_run => 4330 } );

    my $single = $schema->resultset('Run')->find( { id_run => 95 } );

    foreach my $run (($one_of_two_active, $active_one_of_two, $single)) {
      $run->instrument->update_instrument_status('planned repair','pipeline');
    }
    
    lives_ok { $one_of_two_active->update_run_status('run cancelled')}
             'Run cancelled on a HiSeq with another active run';
    is( $one_of_two_active->instrument->current_instrument_status(),
        'planned repair', 'Instrument status is not changed' );
    lives_ok { $active_one_of_two->update_run_status('run cancelled')}
             'Run cancelled on a HiSeq with no other active run';
    is( $active_one_of_two->instrument->current_instrument_status(),
        'down for repair', 'Instrument status is now \'down for repair\'' );

    lives_ok { $single->update_run_status('run cancelled') }
             'Run cancelled on a GAII';
    is( $single->instrument->current_instrument_status(),
        'down for repair', 'Instrument status is now \'down for repair\'' );

    $active_one_of_two->instrument->update_instrument_status('planned repair','pipeline');
    $single->instrument->update_instrument_status('planned repair','pipeline');

    lives_ok { $one_of_two_active->update_run_status('run complete')}
             'Run complete on a HiSeq with another active run';
    is( $one_of_two_active->instrument->current_instrument_status(),
        'planned repair', 'Instrument status is not changed' );
    lives_ok { $active_one_of_two->update_run_status( 'run complete')}
             'Run complete on a HiSeq with no other active run';
    is( $one_of_two_active->instrument->current_instrument_status(),
        'planned repair', 'Instrument status is not changed' );

    lives_ok { $active_one_of_two->update_run_status('run mirrored')}
             'Run mirrored on a HiSeq with no other active run';   
    is( $active_one_of_two->instrument->current_instrument_status(),
        'down for repair', 'Instrument status is now \'down for repair\'' );

    lives_ok { $single->update_run_status('run complete') }
             'Run complete on a GAII';
    is( $single->instrument->current_instrument_status(),
        'planned repair', 'Instrument status has not changed' );
    lives_ok { $single->update_run_status('run mirrored') }
             'Run mirrored on a GAII';
    is( $single->instrument->current_instrument_status(),
        'down for repair', 'Instrument status is now \'down for service\'' );
    
    $active_one_of_two->instrument->update_instrument_status('planned service','pipeline');
    $single->instrument->update_instrument_status('planned service','pipeline');

    lives_ok { $one_of_two_active->update_run_status('analysis pending','pipeline')}
             'analysis pending on a HiSeq with another active run';
    is( $one_of_two_active->instrument->current_instrument_status(),
        'planned repair', 'Instrument status is not changed' );
    lives_ok { $active_one_of_two->update_run_status('analysis pending','pipeline')}
             'analysis pending on a HiSeq with no other active run';
    is( $active_one_of_two->instrument->current_instrument_status(),
        'down for service', 'Instrument status changed to down for service' );

    $active_one_of_two->instrument->update_instrument_status('up','pipeline');
    $single->instrument->update_instrument_status('up','pipeline');

    my $date = $active_one_of_two->get_time_now();
    $date->add_duration(DateTime::Duration->new(seconds => 1));
    my $new = $active_one_of_two->update_run_status('run cancelled',undef,$date);
    ok( $new->iscurrent, 'new status is current');
    is( $new->related_resultset('run_status_dict')->next->description,
      'run cancelled', 'new current run status is "run cancelled"');
    is( $active_one_of_two->instrument->current_instrument_status(),
        'wash required', 'Instrument status changed to wash required' );

    $new = $single->update_run_status('run cancelled','pipeline',$date);
    ok( $new->iscurrent, 'new status is current');
    is( $new->related_resultset('run_status_dict')->next->description,
      'run cancelled', 'new current run status is "run cancelled"');
    is( $single->instrument->current_instrument_status(),
        'wash required', 'Instrument status changed to wash required' );
}

{ #check single read run
    my$r = $schema->resultset('Run')->find(6699);
    ok ($r, 'single read run');
    lives_and {cmp_ok($r->forward_read->expected_cycle_count, '==', 54, ' expected cycle count')} 'forward read';
    lives_and {is($r->reverse_read, undef, ' undefined')} 'reverse read';
}
{ #check paired read run
    my$r = $schema->resultset('Run')->find(6670);
    ok ($r, 'paired read run');
    lives_and {cmp_ok($r->forward_read->expected_cycle_count, '==', 100, ' expected cycle count')} 'forward read';
    lives_and {cmp_ok($r->reverse_read->expected_cycle_count, '==', 100, ' expected cycle count')} 'reverse read';
}
{ #check single read plexed run
    my$r = $schema->resultset('Run')->find(6588);
    ok ($r, 'single read plexed run');
    lives_and {cmp_ok($r->forward_read->expected_cycle_count, '==', 50, ' expected cycle count')} 'forward read';
    lives_and {is($r->reverse_read, undef, ' undefined')} 'reverse read';
}
{ #check paired read plexed run
    my$r = $schema->resultset('Run')->find(6668);
    ok ($r, 'paired read plexed run');
    lives_and {cmp_ok($r->forward_read->expected_cycle_count, '==', 100, ' expected cycle count')} 'forward read';
    lives_and {cmp_ok($r->reverse_read->expected_cycle_count, '==', 100, ' expected cycle count')} 'reverse read';
}

# Find current status - alter count
{
    my$r = $schema->resultset('Run')->find($test_run_id);
    my $crs = $r->current_run_status();
    $crs->update({iscurrent=>0});

    is( $r->current_run_status_description(), undef,
        'Return undef for no current run status' );

  TODO: { local $TODO = 'hope to get this working with a suitable database schema/constraint and relationship';
    $r->run_statuses->update({iscurrent=>1});
    dies_ok { $r->current_run_status_description()} 'Dies for multiple current run statuses' ;
  }
}

1;
