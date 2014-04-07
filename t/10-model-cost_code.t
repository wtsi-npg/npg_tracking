use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;
use t::util;

BEGIN {
  use_ok( q{npg::model::cost_code} );
}
my $util = t::util->new({ fixtures => 1 });
{
  my $cost_code;
  lives_ok {
    $cost_code = npg::model::cost_code->new({
      util => $util,
    });
  } q{create cost_code object ok};
  isa_ok( $cost_code, q{npg::model::cost_code}, q{$cost_code} );

  my $cost_codes = $cost_code->cost_codes();
  isa_ok( $cost_codes, q{ARRAY}, q{$cost_code->cost_codes()} );

  my $r_and_d = $cost_codes->[0];
  isa_ok( $r_and_d, q{npg::model::cost_code}, q{first one} );

  is( $r_and_d->groupname(), q{R&D}, q{first codes group is R&D} );  

}

{
  my $cost_code;
  lives_ok {
    $cost_code = npg::model::cost_code->new({
      id_cost_code => 1,
      util         => $util,
    });
  } q{create cost_code object ok with id_cost_code};
  is( $cost_code->cost_code(), q{S1234}, q{cost_code ok} );
}

{
  my $cost_code;
  lives_ok {
    $cost_code = npg::model::cost_code->new({
      cost_code => q{S1237},
      util      => $util,
    });
  } q{create cost_code object ok with cost_code};
  is( $cost_code->id_cost_code(),  4, q{id_cost_code ok} );
  is( $cost_code->id_cost_group(), 2, q{id_cost_group ok} );
}
1;
