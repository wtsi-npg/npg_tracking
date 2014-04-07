use strict;
use warnings;
use Test::More tests => 25;
use Test::Exception::LessClever;
use t::util;
use t::dbic_util;
use DateTime;
use File::Temp qw{ tempdir };

BEGIN {
  use_ok( q{npg::email::event} );
}

my $event_type = q{status_change};
my $entity_type = q{run_status};

local $ENV{dev} = 'test';
my $dbic_util = t::dbic_util->new();
my $schema_connection = $dbic_util->test_schema();
my $util      = t::util->new();
$util->catch_email($util);
my $tmpdir = tempdir(UNLINK => 1);

{

  my $notify;
  lives_ok {
    $notify = npg::email::event->new();
  } q{object creation ok although no entity_type};
  is( $notify, undef, q{undef when no entity_type provided} );

  lives_ok {
    $notify = npg::email::event->new({
      entity_type => $entity_type,
    });
  } q{object creation ok although no event_type};
  is( $notify, undef, q{undef when no event_type provided} );

  lives_ok {
    $notify = npg::email::event->new({
      entity_type => q{foo},
      event_type  => q{bar},
    });
  } q{object creation ok although no suitable entity_type or event_type};
  is( $notify, undef, q{undef when no suitable class found} );

  my $data = {
    event_row         => $schema_connection->resultset('Event')->find(23),
    schema_connection => $schema_connection,
    log_file_path     => $tmpdir,
    log_file_name     => q{test_log},
  };

  lives_ok {
    $notify = npg::email::event->new( $data );
  } q{object creation ok with suitable values in event_row};
  ok( $notify, q{found object as legitimate values in event_row provided} );
  my ( $temp_entity_type ) = $entity_type =~ m{(.*)_status}xms;
  isa_ok( $notify, q{npg::email::event::} . $event_type . q{::} . $temp_entity_type, q{$notify} );

  $data = {
    id_event          => 23,
    schema_connection => $schema_connection,
    log_file_path     => $tmpdir,
    log_file_name     => q{test_log},
    event_type        => $event_type,
    entity_type       => $entity_type,
  };

  lives_ok {
    $notify = npg::email::event->new( $data );
  } q{object creation ok with suitable entity_type and event_type};
  ok( $notify, q{found object as legitimate event_type and entity_type provided} );
  isa_ok( $notify, q{npg::email::event::} . $event_type . q{::} . $temp_entity_type, q{$notify} );

  $data = {
    event_row         => $schema_connection->resultset('Event')->find(25),
    schema_connection => $schema_connection,
    log_file_path     => $tmpdir,
    log_file_name     => q{test_log},
  };

  lives_ok {
    $notify = npg::email::event->new( $data );
  } q{object creation ok with suitable values (status change, instrument_status) in event_row};
  ok( $notify, q{found object as legitimate values in event_row provided} );
  isa_ok( $notify, q{npg::email::event::} . $event_type . q{::instrument}, q{$notify} );

  $data->{event_row} = $schema_connection->resultset('Event')->find(28);

  lives_ok {
    $notify = npg::email::event->new( $data );
  } q{object creation ok with suitable values (annotation, instrument) in event_row};
  ok( $notify, q{found object as legitimate values in event_row provided} );
  isa_ok( $notify, q{npg::email::event::annotation::instrument}, q{$notify} );

  $data->{event_row} = $schema_connection->resultset('Event')->find(29);

  lives_ok {
    $notify = npg::email::event->new( $data );
  } q{object creation ok with suitable values (annotation, run) in event_row};
  ok( $notify, q{found object as legitimate values in event_row provided} );
  isa_ok( $notify, q{npg::email::event::annotation::run}, q{$notify} );

  $data->{event_row} = $schema_connection->resultset('Event')->find(30);

  lives_ok {
    $notify = npg::email::event->new( $data );
  } q{object creation ok with suitable values (annotation, run_lane) in event_row};
  ok( $notify, q{found object as legitimate values in event_row provided} );
  isa_ok( $notify, q{npg::email::event::annotation::run_lane}, q{$notify} );
}

1;
