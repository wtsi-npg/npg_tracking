#########
# Author:        jo3
# Maintainer:    $Author: jo3 $
# Created:       2010-06-15
# Last Modified: $Date: 2010-10-21 17:20:43 +0100 (Thu, 21 Oct 2010) $
# Id:            $Id: 34-monitor-instrument.t 11439 2010-10-21 16:20:43Z jo3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/34-monitor-instrument.t $
#
use strict;
use warnings;
use English qw(-no_match_vars);

use Test::More tests => 8;
use Test::Exception::LessClever;

use lib q{t};
use t::dbic_util;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 11439 $ =~ /(\d+)/msx; $r; };


local $ENV{dev} = 'test';
my $mock_schema = t::dbic_util->new ( { db_to_use => q{mysql}, })->test_schema();
my $test;

local $INC{'npg_common/run/folder_validation.pm'} = 1;


use_ok('Monitor::Instrument');

my $pattern = 'Required[ ]option[ ]missing:[ ]ident'
            . '|Mandatory[ ]parameter[ ]\'ident\'[ ]missing';
throws_ok { $test = Monitor::Instrument->new_with_options() }
           qr/$pattern/msx,
          'Constructor requires ident argument...';

lives_ok {
            $test = Monitor::Instrument->new(
                ident   => 1,
                _schema => $mock_schema,
            )
         }
         'Object creation ok';

isa_ok( $test->schema(), 'npg_tracking::Schema', 'Schema' );


is( $test->db_entry(), undef, 'No db entry returned' );


$test = Monitor::Instrument->new( ident => 3, _schema => $mock_schema );

lives_ok { $test->db_entry() } 'Retrieve database row';
isa_ok( $test->db_entry(), 'npg_tracking::Schema::Result::Instrument' );


# This test fails with leap seconds. Oh no!
like(
    $test->mysql_time_stamp(),
    qr{^ \d{4}-[01]\d-[0-3]\d  [ ]  [012]\d:[0-5]\d:[0-5]\d  \z}msx,
    'MySQL time stamp'
);

1;

