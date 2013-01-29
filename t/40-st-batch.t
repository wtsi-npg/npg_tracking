#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-03-01 10:36:10 +0000 (Thu, 01 Mar 2012) $
# Id:            $Id: 40-st-batch.t 15277 2012-03-01 10:36:10Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/40-st-batch.t $
#
use strict;
use warnings;
use Test::More tests => 2;

use_ok('st::api::batch');
my $batch = st::api::batch->new();
isa_ok($batch, 'st::api::batch');

1;
