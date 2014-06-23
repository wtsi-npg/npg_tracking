#########
# Author:        Jennifer Liddle (js10@sanger.ac.uk)
# Created:       2012_03_09
#

use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use t::dbic_util;

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/npg_api';

use_ok('npg::sensors');
my $schema =  t::dbic_util->new->test_schema();

my $test = npg::sensors->new();
isa_ok( $test, 'npg::sensors', 'Correct class' );
$test = npg::sensors->new({schema => $schema});
isa_ok( $test, 'npg::sensors', 'Correct class' );

lives_ok { $test->load_data() } 'loads data OK';
lives_ok { $test->post_data() } 'posts data OK';
lives_ok { $test->main() } 'runs main OK';

1;
