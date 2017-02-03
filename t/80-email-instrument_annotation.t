use strict;
use warnings;
use DateTime;
use DateTime::Format::MySQL;
use Perl6::Slurp;
use Test::More tests => 14;
use Test::Deep;
use Test::Exception;
use Test::MockModule;

use t::dbic_util;
use t::util;

local $ENV{dev} = 'test';
my $schema    = t::dbic_util->new->test_schema();
my $util      = t::util->new();
$util->catch_email($util);

BEGIN {
  use_ok( q{npg::email::event::annotation::instrument} );
}

my $event_row = $schema->resultset('Event')->find(28);

my $test;
lives_ok { $test = npg::email::event::annotation::instrument->new(
       { event_row   => $event_row, schema_connection => $schema, }) } q{Can create with event row object};

is( $test->template(), q{instrument_annotation.tt2}, q{correct template name obtained} );
is( $test->user(), q{pipeline}, q{user returns username} );
is( $test->event_row->description(), q{pipeline annotated instrument HS8 - Monitor lane 8 in subsequent runs for right edge of tiles 51-100 out of focus.}, q{annotation retrieved from description} );

lives_ok { $test->compose_email() } q{compose email runs ok};

my $email = q{This email was generated from a test as part of the development process of the NPD group. If you are reading this, the test failed as the email should not have 'escaped' and actually have been sent. (Or it was you that was running the test.)

Please ignore the contents below, and apologies for the inconvenience.


Instrument HS8 has had the following annotation added in NPG tracking.

pipeline annotated instrument HS8 - Monitor lane 8 in subsequent runs for right edge of tiles 51-100 out of focus.

You can get more detail about the instrument through NPG:

http://npg.sanger.ac.uk/perl/npg/instrument/HS8

NPG, DNA Pipelines Informatics

};

my @expected_lines = split /\n/xms, $email;
my @obtained_lines = split /\n/xms, $test->next_email();
is_deeply( \@obtained_lines, \@expected_lines, q{generated email is correct} );

my $watchers = $test->watchers( q{engineers} );
is_deeply( $watchers, [ qw{joe_engineer@sanger.ac.uk} ], q{watchers for engineers is correct} );

lives_ok { $test->run(); } q{run method ok};

$email = $util->parse_email( $util->{emails}->[0] );
is( $email->{subject}, q{Instrument HS8 has been annotated by pipeline} . qq{\n}, q{subject is correct} );
is( $email->{to}, q{joe_engineer@sanger.ac.uk} . qq{\n}, q{joe_engineer is the recipient} );
is( $email->{from}, q{srpipe@sanger.ac.uk} . qq{\n}, q{from is correct} );
@obtained_lines = split/\n/xms, $email->{annotation};
is_deeply( \@obtained_lines, \@expected_lines, q{email body is correct} );

ok( $event_row->notification_sent(), q{notification recorded} );

1;
