use strict;
use warnings;
use English qw(-no_match_vars);

use Test::More tests => 12;
use Test::Deep;
use Test::Exception::LessClever;
use Test::MockModule;

use t::dbic_util;

use Readonly;

Readonly::Scalar my $ABSURD_ID => 100_000_000;

$ENV{DBIC_TRACE} = 0;

use_ok( q{npg_tracking::Schema::Result::RunStatus} );


my $schema = t::dbic_util->new->test_schema();
my $test;

lives_ok { $test = $schema->resultset( q{RunStatus} )->new({}) } q{Create test object};

isa_ok( $test, q{npg_tracking::Schema::Result::RunStatus}, q{$test} );

my $rs;
lives_ok {
  $rs = $schema->resultset( q{RunStatus} )->search({
    id_run_status => 1,
  });
} q{obtain a result set ok};

isa_ok( $rs, q{DBIx::Class::ResultSet}, q{$rs} );

my $row = $rs->next();

is( $row->id_run(), 1, q{id_run obtained correctly} );

is( $row->description(), q{run pending}, q{description is correct} );


my $row2;
throws_ok {
  $row2 = $row->update_run_status( {} );
} qr{No[ ]description[ ]provided}, q{update a run_status - fail no description};


lives_ok {
  $row2 = $row->update_run_status( {
    description => q{run in progress},
    id_run => 1,
    username => q{pipeline},
  } );
} q{update a run_lane status - success};

note $row2;
my $run = $row->run();
is( $run->current_run_status_description(), q{run in progress}, q{current run status correct} );


my $event_row;
lives_ok {
  $event_row = $schema->resultset( q{Event} )->search({
    id_event_type => 1, id_user => 7, entity_id => $row2->id_run_status(),
  })->first();
} q{obtain saved event result set ok};
like( $event_row->description(), qr{run[ ]in[ ]progress[ ]for[ ]run[ ]IL1_1}, q{description saved in event looks correct} );

1;
