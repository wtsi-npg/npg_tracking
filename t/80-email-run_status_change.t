use strict;
use warnings;
use DateTime;
use DateTime::Format::MySQL;
use English qw{-no_match_vars};
use Perl6::Slurp;
use Test::More tests => 37;
use Test::Deep;
use Test::Exception::LessClever;
use Test::MockModule;
use LWP::UserAgent;
use HTTP::Response;

diag "\n***To avoid sending messages to live and dev sites, in this test LWP::UserAgent::post is replaced by a stub***\n\n";
*LWP::UserAgent::post = *main::post_nowhere;

use t::dbic_util;
use t::util;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 16411 $ =~ /(\d+)/msx; $r; };

sub post_nowhere {
  diag "Posting nowhere...\n";
  return HTTP::Response->new(200);
}


local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/email';
local $ENV{dev} = 'test';
my $schema    = t::dbic_util->new->test_schema();
my $util      = t::util->new();
$util->catch_email($util);

my @test;

use_ok('npg::email::event::status_change::run');

lives_ok { $test[0] = npg::email::event::status_change::run->new(
                    { event_row   => $schema->resultset('Event')->find(23),
                      schema_connection => $schema,})
         }
         'Can create with event row object';

lives_ok { $test[1] = npg::email::event::status_change::run->new(
                    { id_event    => 24,
                      schema_connection => $schema,})
         }
         'Can create with id_event';

throws_ok { npg::email::event::status_change::run->new(
                {
                    event_row   => $schema->resultset('Event')->find(23),
                    id_event    => 24,
                    schema_connection => $schema, })
          }
        qr{Mismatched event_row and id_event constructor arguments}ms,
        'If both are supplied they must agree';

throws_ok { my $fail = npg::email::event::status_change::run->new(
                    { id_event    => 25,
                      schema_connection => $schema, });
            $fail->entity();
          }
          qr{Constructor argument is not a npg_tracking::Schema::Result::RunStatus event}ms,
          'Event must be a run status event';

like( $test[0]->template(), qr/run_status_change[.]tt2/msx, 'Template looks right' );

is( $test[0]->id_event(), 23, 'Return the correct id_event' );
is( $test[0]->entity->id_run_status(), 4, 'Return correct id_run_status' );
is( $test[0]->id_run(), 2, 'Return correct id_run' );
is( $test[0]->status_description(), 'run in progress', 'Return correct description field' );
cmp_bag( $test[0]->watchers(),
         ['joe_engineer@sanger.ac.uk', 'full@address.already', 'joe_results@sanger.ac.uk'],
       'Return correct list of watchers' );

isnt( $test[0]->dev(), 'live', '$dev is NOT set to \'live\'' );

my $lane_detail = eval do { local $/; <DATA>; };

cmp_deeply( $test[0]->batch_details(), 
            { batch_id => 4861,
              error    => q{},
              lanes    => $lane_detail }, 'Return correct batch details' );

my $bd = $test[1]->batch_details();
is($bd->{batch_id}, undef, 'batch id undefined');
like($bd->{error}, qr/Attribute \(batch_id\) does not pass the type constraint because: Validation failed .+ with value 0/, 'Error string for batch id zero is correct');

lives_ok {  $test[2] = npg::email::event::status_change::run->new(
                    { id_event    => 26,
                      schema_connection => $schema,})
         } 'Create a new test object';
like($test[2]->batch_details()->{error}, qr/Attribute \(position\) does not pass the type constraint because: Validation failed for 'NpgTrackingLaneNumber' (failed\s)?with value 10/, 'Error string for batch with too many lanes');

my $email_template;
lives_ok { $email_template = $test[0]->compose_email() } 'Compose email works';

# To test the content of the emails generated, just check that the relevant
# elements are in there, without fussing about an exact string match. The
# latter would be easier, and more accurate, but more tedious to maintain.

my $path = $test[0]->email_templates_location();
my $header      = slurp( qq{$path/devel_header.tt2} );
my $signature   = slurp( qq{$path/signature.tt2} );
my $npg_run_url = slurp( qq{$path/npg_tracking_web_url.tt2} );


my $lane_detail_re = qr{};
foreach my $i ( @{ $test[0]->batch_details->{lanes} } ) {
    $lane_detail_re .= qr{$i->{position}.+$i->{library}.+}ms;
}


isa_ok( $email_template, 'Template', 'Compose email output' );

# Template v2.22 (more than a year old now) reports q{} here - v2.19, on the
# seqfarm returns undef
my $error = $email_template->error();
ok( ( ( !defined $error ) || ( $error eq q{} ) ), 'No Template errors' );
like( $test[0]->email_body_store()->[0], qr{^\Q$header\E}ms,
      'Non-live emails have a special header' );


# Make sure the header isn't included in live emails.
# Be careful not to test send in this block.
{
    local $ENV{dev} = 'live';

    lives_ok { 
                $test[3] = npg::email::event::status_change::run->new(
                     { event_row   => $schema->resultset('Event')->find(23),
                       schema_connection => $schema,}
                );
                $test[3]->compose_email();
             }
             'Create a sandboxed test object...';
    is( $test[3]->dev(), 'live', ' ...that thinks it\'s live' );

    unlike( $test[3]->email_body_store()->[0], qr{^$header}ms,
          'Live emails have no special header' );
}

like( $test[0]->email_body_store()->[0],
      qr{(?:Lane - \d+: Library - .+\n){8}}ms,
      'The lane template has been processed' );

like( $test[0]->email_body_store()->[0],
      qr{$lane_detail_re}ms,
      'The relevant lane details have been included' );

like( $test[0]->email_body_store()->[0], qr{$npg_run_url}ms,
      'NPG run page address has been included' );

like( $test[0]->email_body_store()->[0], qr{$signature$}ms,
      'Signature has been included' );

my $reports;
lives_ok { $reports = $test[0]->compose_st_reports() } 'compose_st_reports survives';

my $expect = all( isa("st::api::event"),
                  methods(
                    eventful_type => 'Request',
                    eventful_id   => re(qr/^\d+$/msx),
                    family        => 'update',
                    identifier    => 2,
                    key           => 'run in progress',
                    location      => re(qr/^\d$/msx),
                    message       => 'Run 2 : run in progress',
                  )
);

cmp_deeply( $reports, array_each($expect), 'The reports are well formed' );
cmp_deeply( $reports->[2],
            methods(
                    eventful_type => 'Request',
                    eventful_id   => 25008,
                    family        => 'update',
                    identifier    => 2,
                    key           => 'run in progress',
                    location      => 3,
                    message       => 'Run 2 : run in progress',
            ),
            'Details are correct for the 3rd one'
);

lives_ok { $test[0]->run() } 'Main method executes without error';

my $updated_time = $test[0]->event_row->notification_sent();
my $lag = DateTime->now()->subtract_datetime($updated_time)->delta_seconds();
ok( abs($lag) < 10, 'notification_sent field has been updated recently' );

{
    local $ENV{dev} = 'dev';
    lives_ok { 
                $test[4] = npg::email::event::status_change::run->new(
                     { event_row   => $schema->resultset('Event')->find(23),
                       schema_connection => $schema,}
                );
                $test[4]->compose_email();
             }
             'Create another sandboxed test object...';

    is( $test[4]->dev(), 'dev', ' ...that thinks it\'s dev' );
    my $watchers = $test[4]->watchers();
    is( $watchers->[0], $ENV{USER} . $test[4]->default_recipient_host(),
          'Non-live, non-test emails will only go to the caller' );
    is( scalar @{$watchers}, 1, '...and no-one else' );
}

1;
__DATA__
[
    {
        position     => 1,
        control      => 0,
        request_id   => 24939,
        req_ent_name => 'request',
        library      => 'Vietnam Shigella 5 1'
    },
    {
        position     => 2,
        control      => 0,
        request_id   => 24962,
        req_ent_name => 'request',
        library      => 'Vietnam Shigella 6 1'
    },
    {
        position     => 3,
        control      => 0,
        request_id   => 25008,
        req_ent_name => 'request',
        library      => 'Vietnam Shigella 8 1'
    },
    {
        position     => 4,
        control      => 1,
        request_id   => 43829,
        req_ent_name => 'request',
        library      => 'phiX CT1462-2 1'
    },
    {
        position     => 5,
        control      => 0,
        request_id   => 27478,
        req_ent_name => 'request',
        library      => 'Group 10 1'
    },
    {
        position     => 6,
        control      => 0,
        request_id   => 2912207,
        req_ent_name => 'request',
        library      => 'Timepoint5 1'
    },
    {
        position     => 7,
        control      => 0,
        request_id   => 29056,
        req_ent_name => 'request',
        library      => 'Baker pool 1 1'
    },
    {
        position     => 8,
        control      => 0,
        request_id   => 26283,
        req_ent_name => 'request',
        library      => 'S aureus pool 4 1'
    },
]
