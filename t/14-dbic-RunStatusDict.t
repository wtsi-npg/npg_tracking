use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;

use t::dbic_util;

use_ok('npg_tracking::Schema::Result::RunStatusDict');

my $schema = t::dbic_util->new->test_schema();

my $row = $schema->resultset('RunStatusDict')->find({description => 'analysis in progress'});
isa_ok ($row, 'npg_tracking::Schema::Result::RunStatusDict');
is ($row->description, 'analysis in progress', 'correct description');
is ($row->temporal_index, 240, 'correct temporal index');

throws_ok {$row->compare_to_status_description()}
  qr/Non-empty status description string required/,
  'error if argument description is undefined';
throws_ok {$row->compare_to_status_description(q[])}
  qr/Non-empty status description string required/,
  'error if argument description is an empty string';

is ($row->compare_to_status_description('qc on hold'), -1, "is less than status 'qc on hold'");
is ($row->compare_to_status_description('run in progress'), 1, "is more than status 'run in progress'");
is ($row->compare_to_status_description($row->description), 0, 'is equal to its own status description');

1;
