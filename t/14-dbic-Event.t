use strict;
use warnings;
use Test::More tests => 14;
use Test::Exception;
use DateTime;
use t::dbic_util;

use_ok('npg_tracking::Schema::Result::Event');

my $schema = t::dbic_util->new->test_schema();

my $test;
lives_ok {
           $test = $schema->resultset('Event')->create(
                        {
                          id_event_type     => 1,
                          date              => '2010-09-01 17:30:03',
                          description       => 'Some text',
                          entity_id         => 6,
                          id_user           => 6,
                        }
           )
         }
         'Create test object - notification_sent not set';
isa_ok( $test, 'npg_tracking::Schema::Result::Event', 'Correct class' );

is( $test->get_column('notification_sent'), '0000-00-00 00:00:00',
  'Zeroed date written to db...' );
is( $test->notification_sent(), undef, '  ...but undef is returned to DBIx');

lives_ok { $test->mark_as_reported() } 'Row is marked as reported';
my $date = $test->notification_sent();
ok($date, 'Notification date is set');

my $diff = $test->get_time_now()->subtract_datetime($date);
ok($diff->is_zero || $diff->is_positive, 'Notification timestamp is not in future');
ok($diff->minutes <= 1, 'Notification time is in the recent past');

lives_ok {
           $test = $schema->resultset('Event')->create(
                        {
                          id_event_type     => 1,
                          date              => '2010-09-21 11:19:23',
                          description       => 'Some more text',
                          entity_id         => 7,
                          id_user           => 6,
                          notification_sent => '2010-09-21 11:19:25',
                        }
           )
         }
         'Create test object - notification_sent is set';

is( $test->notification_sent()->datetime, '2010-09-21T11:19:25',
    'Notification_sent returned correctly');
my $id = $test->id_event();
throws_ok { $test->mark_as_reported() }
  qr/Event with id $id is already marked as reported/,
  'Cannot mark as reported twice';

$test = $schema->resultset('Event')->find(23);
my $entity = $test->entity_obj();
isa_ok( $entity, 'npg_tracking::Schema::Result::RunStatus',
        'Original entity' );
is( $entity->id_run_status(), 4, 'The entity id matches' );

1;
