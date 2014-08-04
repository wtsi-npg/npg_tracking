use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;

use t::dbic_util;

use_ok( q{npg_tracking::Schema::Result::RunStatus} );

my $schema = t::dbic_util->new->test_schema();

my $rs;
lives_ok {
  $rs = $schema->resultset( q{RunStatus} )->search({
    id_run_status => 1,
  });
} q{obtain a result set ok};

isa_ok( $rs, q{DBIx::Class::ResultSet}, q{$rs} );

my $row = $rs->next();
isa_ok( $row, q{npg_tracking::Schema::Result::RunStatus});
is( $row->id_run(), 1, q{id_run obtained correctly} );
is( $row->description(), q{run pending}, q{description is correct} );

1;
