use strict;
use warnings;
use t::util;
use Test::More tests => 4;

use_ok('npg::model::instrument_designation');

my $util = t::util->new({fixtures => 1});

{
  my $instr_des = npg::model::instrument_designation->new();
  isa_ok( $instr_des, 'npg::model::instrument_designation' );
}

{
    my $id = npg::model::instrument_designation->
        new( {
               util                      => $util,
               id_instrument_designation => 3,
             }
    );

    is( $id->id_instrument(), '34', 'retrieve correct id_instrument' );
    is( $id->id_designation(), '3', 'retrieve correct id_designation' );
}

1;
