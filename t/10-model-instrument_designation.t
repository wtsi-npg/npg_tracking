#########
# Author:        jo3
# Maintainer:    $Author: mg8 $
# Created:       2009-01-20
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-instrument_designation.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-instrument_designation.t $
#

use strict;
use warnings;
use t::util;
use Test::More tests => 4;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

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
