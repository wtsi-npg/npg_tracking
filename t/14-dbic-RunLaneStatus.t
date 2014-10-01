use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;
use DateTime;

use t::dbic_util;

use_ok( q{npg_tracking::Schema::Result::RunLaneStatus} );

my $schema = t::dbic_util->new->test_schema();
my $test;

lives_ok { $test = $schema->resultset( q{RunLaneStatus} )->new({}) } q{Create test object};

isa_ok( $test, q{npg_tracking::Schema::Result::RunLaneStatus}, q{$test} );

my $rs;
lives_ok {
  $rs = $schema->resultset( q{RunLaneStatus} )->search({
    id_run_lane_status => 1,
  });
} q{obtain a result set ok};

isa_ok( $rs, q{DBIx::Class::ResultSet}, q{$rs} );

my $row = $rs->next();

is( $row->id_run_lane(), 1, q{id_run_lane obtained correctly} );

is( $row->description(), q{analysis in progress}, q{description is correct} );

is( $row->id_run(), 1, q{id_run is correct} );

is( $row->position(), 7, q{position is correct} );


1;
