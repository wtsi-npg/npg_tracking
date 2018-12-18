use strict;
use warnings;
use Test::More tests => 5;
use t::dbic_util;

use_ok('npg_tracking::Schema::Result::InstrumentStatusDict');

my $schema = t::dbic_util->new->test_schema();

my $row = $schema->resultset('InstrumentStatusDict')
                 ->find({description => 'down for service'});
ok ($row, 'row retrieved');
isa_ok ($row, 'npg_tracking::Schema::Result::InstrumentStatusDict');
is($row->iscurrent, 1, 'status is current');
is($row->description, 'down for service', 'correct description');

1;
