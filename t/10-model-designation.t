use strict;
use warnings;
use t::util;
use Test::More tests => 3;

use_ok('npg::model::designation');

my $util = t::util->new({fixtures => 1});

{
    my $designation = npg::model::designation->new();
    isa_ok( $designation, 'npg::model::designation' );
}

{
    my $desig = npg::model::designation->new( {
                                                util           => $util,
                                                id_designation => 2,
                                              }
    );

    is( $desig->description(), 'R&D', 'retrieve correct designation' );
}

1;
