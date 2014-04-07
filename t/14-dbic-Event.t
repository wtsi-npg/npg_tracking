use strict;
use warnings;

use DBI;
use English qw(-no_match_vars);

use Test::More tests => 9;
use Test::Exception::LessClever;
use Test::MockModule;

use t::dbic_util;

use_ok('npg_tracking::Schema::Result::Event');


my $schema = t::dbic_util->new->test_schema();
my $dsn    = $schema->storage->_connect_info->[0];


my $test;

lives_ok {
           $test = $schema->resultset('Event')->create(
                        {
                          id_event_type     => 1,
                          date              => '2010-09-01 17:30:03',
                          description       => 'Some text',
                          entity_id         => 6,
                          id_user           => 6,
#                          notification_sent => undef,
                        }
           )
         }
         'Create test object - notification_sent not set';
isa_ok( $test, 'npg_tracking::Schema::Result::Event', 'Correct class' );

my $new_row_id = $test->id();


my $dbh = DBI->connect($dsn);
my $sql = 'SELECT notification_sent'
        . ' FROM event'
        . " WHERE id_event = $new_row_id";
my $blank_date = $dbh->selectrow_array($sql);

is( $blank_date, '0000-00-00 00:00:00', 'Zeroed date written to db...' );
is( $test->notification_sent(), undef, '  ...but undef is returned to DBIx');


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
    'notification_sent returned correctly');


$test = $schema->resultset('Event')->find(23);
my $entity = $test->entity_obj();
isa_ok( $entity, 'npg_tracking::Schema::Result::RunStatus',
        'Recover entity from event' );
is( $entity->id_run_status(), 4, 'The entity id matches' );

1;
