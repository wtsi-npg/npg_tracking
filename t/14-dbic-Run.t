#########
# Author:        jo3
# Maintainer:    $Author: mg8 $
# Created:       2010_05_26
# Last Modified: $Date: 2012-11-26 09:53:48 +0000 (Mon, 26 Nov 2012) $
# Id:            $Id: 14-dbic-Run.t 16269 2012-11-26 09:53:48Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/14-dbic-Run.t $

use strict;
use warnings;

use POSIX qw(strftime);
use English qw(-no_match_vars);

use Test::More tests => 88;
use Test::Deep;
use Test::Exception::LessClever;
use Test::MockModule;
use Test::Warn;

use t::dbic_util;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 16269 $ =~ /(\d+)/msx; $r; };

use_ok('npg_tracking::Schema::Result::Run');


my $schema = t::dbic_util->new->test_schema();
my $test;


#
# Basic set up.
#


my $test_run_id = 1;

lives_ok {
            $test = $schema->resultset('Run')->
                        find( { id_run => $test_run_id } )
         }
         'Create test object';

isa_ok( $test, 'npg_tracking::Schema::Result::Run', 'Correct class' );


{
    my $event_type_rs = $test->_event_type_rs();
    my $rsd_rs        = $test->_rsd_rs();
    my $tag_rs        = $test->_tag_rs();
    my $user_rs       = $test->_user_rs();

    isa_ok( $event_type_rs, 'npg_tracking::Schema::Result::EventType',
            'Event type result set' );

    isa_ok( $rsd_rs, 'npg_tracking::Schema::Result::RunStatusDict',
            'Run status dict result set' );

    isa_ok( $tag_rs, 'npg_tracking::Schema::Result::Tag',
            'Tag result set' );

    isa_ok( $user_rs, 'npg_tracking::Schema::Result::User',
            'User result set' );
}



# Conventional tests for current_run_status method
{
    is( $test->current_run_status_description(), 'run complete',
        'Current run status returned' );
}


# Status updates.
{
    lives_ok { $test->update_run_status( 'run complete', 'joe_loader' ) }
             'Set a status that is already current';


    my $run_status_rs = $schema->resultset('RunStatus')->search(
        {
            id_run    => $test_run_id,
            iscurrent => 1,
        }
    );


    my $test_date = $run_status_rs->first->date();
    is( $test_date->datetime, '2007-06-05T10:16:55', 'Not changed' );

    my $before = DateTime->now();
    lives_ok { $test->update_run_status( 'run stopped early', 'joe_loader' ) }
             'Set a new status';

    is( $run_status_rs->first->id_run_status_dict(), 22, 'New run status' );
    isnt( $run_status_rs->first->date(), $test_date,
          'New entry is an update not a copy' );
    cmp_ok( $run_status_rs->first->date(), '>=', $before, 'Current date' );

    is( $run_status_rs->count(), 1, 'Only one row has \'iscurrent\' set' );
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

#
# Single/paired tag
#

my $rta_query         = { id_run => $test_run_id,
                          id_tag => 16 };

my $paired_read_query = { id_run => $test_run_id,
                          id_tag => 17 };

my $single_read_query = { id_run => $test_run_id,
                          id_tag => 18 };

my $multiplex_query   = { id_run => $test_run_id,
                          id_tag => 20 };


# Note that SQLite will use the next free ROWID, so we can't use a change in
# the primary key to check that a new row has actually been created.

my $paired_tag_rs = $schema->resultset('TagRun')->search($paired_read_query);

my $single_tag_rs = $schema->resultset('TagRun')->search($single_read_query);

# Make sure we start off in the right place. (This is a test of the test.)
is( $paired_tag_rs->count(), 1, 'Start off with one \'paired\' tag' );
is( $single_tag_rs->count(), 0, 'Start off with no \'single\' tags' );

# Test is_tag_set method while we're here.
is( $test->is_tag_set('paired_read'), 1, 'Predicate test on a set tag' );
is( $test->is_tag_set('single_read'), 0, 'Predicate test on an unset tag' );

my $test_date = $paired_tag_rs->first->date();

{
    # Start over.
    my $tg_rs = $schema->resultset('TagRun');

    $test = $schema->resultset('Run')->new( { id_run => $test_run_id } );

    warning_is { $test->set_tag(3) } { carped => 'No tag supplied.' },
               'Carp about missing tag argument';

    my $tagrun_rs = $tg_rs->search($rta_query);

    is( $tagrun_rs->count(), 0, 'Make sure rta tag is not already set' );

    lives_ok { $test->set_tag( 3, 'rta' ) } 'Use general method to set tag';

    $tagrun_rs = $tg_rs->search($rta_query);

    is( $tagrun_rs->count(), 1, 'rta tag has been set' );

    $tagrun_rs = $tg_rs->search($single_read_query);

    is( $tagrun_rs->count(), 0, 'single_read tag is not already set' );

    lives_ok { $test->set_tag( 3, 'single_read' ) }
             'Same method for paired tags';

    $tagrun_rs = $tg_rs->search($single_read_query);

    is( $tagrun_rs->count(), 1, 'single_read tag has been set' );

    $tagrun_rs = $tg_rs->search($paired_read_query);

    is( $tagrun_rs->count(), 0, 'paired_read tag has been removed' );


    lives_ok { $test->unset_tag( 3, 'rta' ) }
             'Use general method to unset tag';

    $tagrun_rs = $tg_rs->search($rta_query);

    is( $tagrun_rs->count(), 0, 'rta tag has been removed' );

    lives_ok { $test->unset_tag( 3, 'single_read' ) }
             'Same unset method for paired tags';

    $tagrun_rs = $tg_rs->search($single_read_query);

    is( $tagrun_rs->count(), 0, 'single_read tag has been removed' );

    $tagrun_rs = $tg_rs->search($paired_read_query);

    is( $tagrun_rs->count(), 0, 'paired_read tag has not been set' );

    $test->set_tag( 3, 'paired_read' );
    $tagrun_rs = $tg_rs->search($paired_read_query);
    my $row = $tagrun_rs->next();

    # SQLite seems to return datetimes rather than dates.
    my $today = strftime( '%F', localtime );
    like( $row->date(), qr/^$today/msx, 'The date is correct' );

    my $old_date = '1999-04-22';
    $row->date($old_date);
    $row->update();

    $test->set_tag( 3, 'paired_read' );
    $tagrun_rs = $tg_rs->search($paired_read_query);
    like( $tagrun_rs->next->date(), qr/^$old_date/msx,
        'The date is not changed if set_tag is called again for a matched tag'
    );

    $tagrun_rs = $tg_rs->search($multiplex_query);

    is( $tagrun_rs->count(), 1, 'multiplex tag is already set' );
    $row = $tagrun_rs->next();
    $row->date($old_date);
    $row->update();

    $tagrun_rs = $tg_rs->search($multiplex_query);
    like( $tagrun_rs->next->date(), qr/^$old_date/msx,
      'The date is not changed if set_tag is called again for a singleton tag'
    );

}


# Tests for updating instrument status when it is 'planned maintenance'.
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
       my $instrument =  $run->instrument;
       lives_ok {$instrument->update_instrument_status(
                    'planned repair', 'pipeline'
                    )} 'instrument updated to the planned repair'
    }

    lives_ok { 
                $one_of_two_active->update_run_status( 'run cancelled',
                                                       'pipeline' )
             }
             '  Run cancelled on a HiSeq with another active run';

    is( $one_of_two_active->instrument->current_instrument_status(),
        'planned repair', '  Instrument status is not changed' );


    lives_ok { 
                $active_one_of_two->update_run_status( 'run cancelled',
                                                       'pipeline' )
             }
             '  Run cancelled on a HiSeq with no other active run';

    is( $active_one_of_two->instrument->current_instrument_status(),
        'down for repair', '  Instrument status is now \'down for repair\'' );


    lives_ok { $single->update_run_status( 'run cancelled', 'pipeline' ) }
             '  Run cancelled on a GAII';

    is( $single->instrument->current_instrument_status(),
        'down for repair', '  Instrument status is now \'down for repair\'' );


    lives_ok {
                $active_one_of_two->instrument->update_instrument_status(
                                          'planned repair', 'pipeline' );
                $single->instrument->update_instrument_status(
                                          'planned repair', 'pipeline' );
             }
             'Reset instrument statuses';

    lives_ok { 
                $one_of_two_active->update_run_status( 'run complete',
                                                       'pipeline' )
             }
             '  Run complete on a HiSeq with another active run';

    is( $one_of_two_active->instrument->current_instrument_status(),
        'planned repair', '  Instrument status is not changed' );


    lives_ok { 
                $active_one_of_two->update_run_status( 'run complete',
                                                       'pipeline' )
             }
             '  Run complete on a HiSeq with no other active run';

    is( $one_of_two_active->instrument->current_instrument_status(),
        'planned repair', '  Instrument status is not changed' );

    lives_ok { 
                $active_one_of_two->update_run_status( 'run mirrored',
                                                       'pipeline' )
             }
             '  Run mirrored on a HiSeq with no other active run';   

    is( $active_one_of_two->instrument->current_instrument_status(),
        'down for repair', '  Instrument status is now \'down for repair\'' );


    lives_ok { $single->update_run_status( 'run complete', 'pipeline' ) }
             '  Run complete on a GAII';

    is( $single->instrument->current_instrument_status(),
        'planned repair', '  Instrument status has not changed' );

    lives_ok { $single->update_run_status( 'run mirrored', 'pipeline' ) }
             '  Run complete on a GAII';

    is( $single->instrument->current_instrument_status(),
        'down for repair', '  Instrument status is now \'down for service\'' );


    lives_ok {
                $active_one_of_two->instrument->update_instrument_status(
                                          'planned service', 'pipeline' );
                $single->instrument->update_instrument_status(
                                          'planned service', 'pipeline' );
             }
             'Reset instrument statuses';

    lives_ok { 
                $one_of_two_active->update_run_status( 'analysis pending',
                                                       'pipeline' )
             }
             '  analysis pending on a HiSeq with another active run';

    is( $one_of_two_active->instrument->current_instrument_status(),
        'planned repair', '  Instrument status is not changed' );


    lives_ok { 
                $active_one_of_two->update_run_status( 'analysis pending',
                                                       'pipeline' )
             }
             '  analysis pending on a HiSeq with no other active run';

    is( $active_one_of_two->instrument->current_instrument_status(),
        'down for service', '  Instrument status changed to down for service' );


    lives_ok {
               $one_of_two_active->instrument->update_instrument_status(
                                                           'up', 'pipeline' );
               $active_one_of_two->instrument->update_instrument_status(
                                                           'up', 'pipeline' );
               $single->instrument->update_instrument_status(
                                                           'up', 'pipeline' );
             }
             'Set status to "up"';


    lives_ok { 
                $active_one_of_two->update_run_status( 'run cancelled',
                                                       'pipeline' )
             }
             '  Run cancelled on a HiSeq with no other active run';

    is( $active_one_of_two->instrument->current_instrument_status(),
        'wash required', '  Instrument status changed to wash required' );


    lives_ok { $single->update_run_status( 'run cancelled', 'pipeline' ) }
             '  Run cancelled on a GAII';

    is( $single->instrument->current_instrument_status(),
        'wash required', '  Instrument status changed to wash required' );


    lives_ok { 
                $active_one_of_two->update_run_status( 'run cancelled',
                                                       'pipeline' )
             }
             '  Run cancelled on a HiSeq with no other active run';

    is( $active_one_of_two->instrument->current_instrument_status(),
        'wash required', '  Instrument status changed to wash required' );


    lives_ok { $single->update_run_status( 'run cancelled', 'pipeline' ) }
             '  Run cancelled on a GAII';

    is( $single->instrument->current_instrument_status(),
        'wash required', '  Instrument status changed to wasg required' );
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
diag $r->run_statuses->count()." run_statuses for run $test_run_id";
diag $r->run_statuses->search({iscurrent=>1})->count()." current run_statuses for run $test_run_id";
    is( $r->current_run_status_description(), undef,
        'Return undef for no current run status' );

  TODO: { local $TODO = 'hope to get this working with a suitable database schema/constraint and relationship';
    $r->run_statuses->update({iscurrent=>1});
diag $r->run_statuses->search({iscurrent=>1})->count()." current run_statuses for run $test_run_id";
    dies_ok { $r->current_run_status_description()} 'Dies for multiple current run statuses' ;
  }
}

1;
