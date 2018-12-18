use strict;
use warnings;
use Test::More tests => 4;
use t::dbic_util;

use_ok('npg_tracking::Schema::Result::RunLaneStatusDict');

my $schema = t::dbic_util->new->test_schema();

my $row = $schema->resultset('RunLaneStatusDict')
                 ->find({description => 'analysis in progress'});
ok ($row, 'row retrieved');
isa_ok ($row, 'npg_tracking::Schema::Result::RunLaneStatusDict');
is($row->description, 'analysis in progress', 'correct description');

1;
