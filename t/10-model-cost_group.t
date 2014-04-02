use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;
use Test::Deep;
use t::util;

BEGIN {
  use_ok( q{npg::model::cost_group} );
}
my $util = t::util->new({ fixtures => 1 });
{
  my $cost_group;
  lives_ok {
    $cost_group = npg::model::cost_group->new({
      util => $util,
    });
  } q{create cost_group object ok};
  isa_ok( $cost_group, q{npg::model::cost_group}, q{$cost_group} );

  my $cost_groups = $cost_group->cost_groups();
  isa_ok( $cost_groups, q{ARRAY}, q{$cost_group->cost_groups()} );

  my $r_and_d = $cost_groups->[0];
  isa_ok( $r_and_d, q{npg::model::cost_group}, q{first one} );

  is( $r_and_d->name(), q{R&D}, q{first cost_group name is R&D} );  

}

{
  my $cost_group;
  lives_ok {
    $cost_group = npg::model::cost_group->new({
      id_cost_group => 1,
      util         => $util,
    });
  } q{create cost_group object ok with id_cost_group};
  is( $cost_group->name(), q{R&D}, q{cost_group ok} );
  my $codes = [ qw{S1234 S1235 S1236} ];
  is_deeply( $cost_group->group_codes(), $codes, q{group_codes returned ok} );
}

{
  my $cost_group;
  lives_ok {
    $cost_group = npg::model::cost_group->new({
      name => q{Zebrafish Sequencing},
      util => $util,
    });
  } q{create cost_group object ok with name};
  is( $cost_group->id_cost_group(), 2, q{id_cost_group ok} );

  my $codes = [ qw{S1237} ];
  is_deeply( $cost_group->group_codes(), $codes, q{group_codes returned ok} );

  is( $cost_group->ajax_array_cost_group_values( q{R&D} ), q{['S1234','S1235','S1236']}, q{ajax array string ok} );

}

1;
