#########
# Author:        jo3
# Maintainer:    $Author: dj3 $
# Created:       2010_07_29
# Last Modified: $Date: 2010-10-07 13:00:50 +0100 (Thu, 07 Oct 2010) $
# Id:            $Id: 14-dbic-EventType.t 11232 2010-10-07 12:00:50Z dj3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/14-dbic-EventType.t $

use strict;
use warnings;

use English qw(-no_match_vars);

use Test::More tests => 8;
use Test::Exception::LessClever;
use Test::MockModule;

use lib q{t};
use t::dbic_util;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 11232 $ =~ /(\d+)/msx; $r; };


use_ok('npg_tracking::Schema::Result::EventType');


my $schema = t::dbic_util->new->test_schema();
my $test;

lives_ok { $test = $schema->resultset('EventType')->new( {} ) }
         'Create test object';
isa_ok( $test, 'npg_tracking::Schema::Result::EventType', 'Correct class' );


{
    my $entity_type_rs = $test->_entity_type_rs();

    isa_ok( $entity_type_rs, 'npg_tracking::Schema::Result::EntityType',
            'EntityType result set' );
}


{
    throws_ok { $test->id_query(7) }
              qr/Event[ ]type[ ]description[ ]required/msx,
              'Croak without description';

    is( $test->id_query( 6, 'status change' ), 1, 'Correct event type id' );
}


{
    no warnings;
    local *npg_tracking::Schema::Result::EventType::_count
        = sub { return 2; };
    use warnings;

    $test = $schema->resultset('EventType')->new( {} );

    throws_ok { $test->id_query( 6, 'status change' ) }
          qr/Panic![ ]Multiple[ ]event[ ]type[ ]rows[ ]found/msx,
          'Exception thrown for multiple db matches';

    no warnings;
    local *npg_tracking::Schema::Result::EventType::_count
        = sub { return 0; };
    use warnings;

    is( $test->id_query( 6, 'status change' ), undef,
        'Return undef for no matches' );
}

1;
