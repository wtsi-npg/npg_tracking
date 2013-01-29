#########
# Author:        jo3
# Maintainer:    $Author: mg8 $
# Created:       2010_05_26
# Last Modified: $Date: 2012-11-26 09:53:48 +0000 (Mon, 26 Nov 2012) $
# Id:            $Id: 14-dbic-InstrumentStatusDict.t 16269 2012-11-26 09:53:48Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/14-dbic-InstrumentStatusDict.t $

use strict;
use warnings;

use POSIX qw(strftime);
use English qw(-no_match_vars);

use Test::More tests => 15;
use Test::Deep;
use Test::Exception::LessClever;
use Test::MockModule;
use Test::Warn;

use lib q{t};
use t::dbic_util;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 16269 $ =~ /(\d+)/msx; $r; };

Readonly::Scalar my $ABSURD_ID => 100_000_000;

## no critic (ValuesAndExpressions::ProhibitMagicNumbers)

use_ok('npg_tracking::Schema::Result::InstrumentStatusDict');


my $schema = t::dbic_util->new->test_schema();
my $test;


#
# Basic set up.
#


lives_ok {
            $test = $schema->resultset('InstrumentStatusDict')->new( { } )
         }
         'Create test object';

isa_ok( $test, 'npg_tracking::Schema::Result::InstrumentStatusDict',
        'Correct class' );

throws_ok { $test->check_row_validity() }
          qr/Argument required/ms,
          'Exception thrown for no argument supplied';


is( $test->check_row_validity('run exploded'), undef, 'Invalid description' );
is( $test->check_row_validity($ABSURD_ID),     undef, 'Invalid id' );

throws_ok {$test->check_row_validity('planned maintenance')}
  qr/Instrument status \"planned maintenance\" is not current/,
  'non-current row is invalid';

my $row = $test->check_row_validity('down for service');
is(
    ( ref $row ),
    'npg_tracking::Schema::Result::InstrumentStatusDict',
    'Valid description...'
);
is( $row->id_instrument_status_dict(), 10, '...and the correct row' );



$row = $test->check_row_validity(1);

is(
    ( ref $row ),
    'npg_tracking::Schema::Result::InstrumentStatusDict',
    'Valid id...'
);
is( $row->description(), 'up', '...and the correct row' );

my $row2 = $test->_insist_on_valid_row(1);

cmp_deeply( $row, $row2, 'Internal method returns same row' );


{
    my $broken_db_test =
        Test::MockModule->new('DBIx::Class::ResultSet');

    $broken_db_test->mock( count => sub { return 2; } );

    $test = $schema->resultset('InstrumentStatusDict')->new( {} );

    throws_ok { $test->check_row_validity(1) }
              qr/Panic![ ]Multiple[ ]instrument_status_dict[ ]rows[ ]found/msx,
              'Exception thrown for multiple db matches';

    $broken_db_test->mock( count => sub { return 0; } );
    is( $test->check_row_validity(1), undef, 'Return undef for no matches' );

    throws_ok { $test->_insist_on_valid_row(1) }
              qr/Invalid[ ]identifier:[ ]1/msx,
              'Internal validator croaks as it\'s supposed to';
}



1;
