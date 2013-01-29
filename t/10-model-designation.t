#########
# Author:        jo3
# Maintainer:    $Author: mg8 $
# Created:       2009-01-20
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-designation.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-designation.t $
#

use strict;
use warnings;
use t::util;
use Test::More tests => 3;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

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
