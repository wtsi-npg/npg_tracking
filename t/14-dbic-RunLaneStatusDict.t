use strict;
use warnings;
use English qw(-no_match_vars);

use Test::More tests => 10;
use Test::Deep;
use Test::Exception::LessClever;
use Test::MockModule;

use t::dbic_util;

use Readonly;

Readonly::Scalar my $ABSURD_ID => 100_000_000;


use_ok('npg_tracking::Schema::Result::RunLaneStatusDict');


my $schema = t::dbic_util->new->test_schema();
my $test;

lives_ok { $test = $schema->resultset('RunLaneStatusDict')->new( {} ) }
         'Create test object';


throws_ok { $test->check_row_validity() }
          qr/Argument required/ms,
          'Exception thrown for no argument supplied';


is( $test->check_row_validity('lane exploded'), undef, 'Invalid description' );
is( $test->check_row_validity($ABSURD_ID),      undef, 'Invalid id' );

my $row = $test->check_row_validity('analysis in progress');

is(
    ( ref $row ),
    'npg_tracking::Schema::Result::RunLaneStatusDict',
    'Valid description...'
);
is( $row->id_run_lane_status_dict(), 1, '...and the correct row' );



$row = $test->check_row_validity(2);

is(
    ( ref $row ),
    'npg_tracking::Schema::Result::RunLaneStatusDict',
    'Valid id...'
);
is( $row->description(), 'analysis complete', '...and the correct row' );

my $row2 = $test->_insist_on_valid_row(2);

cmp_deeply( $row, $row2, 'Internal method returns same row' );


1;
