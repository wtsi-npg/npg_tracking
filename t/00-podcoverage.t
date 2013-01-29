#########
# Author:        rmp
# Maintainer:    $Author: dj3 $
# Created:       2008-04-28
# Last Modified: $Date: 2010-11-08 15:02:27 +0000 (Mon, 08 Nov 2010) $
# Id:            $Id: 00-podcoverage.t 11663 2010-11-08 15:02:27Z dj3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/00-podcoverage.t $
#

use Test::More;
use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 11663 $ =~ /(\d+)/mx; $r; };

eval "use Test::Pod::Coverage 1.00";
plan skip_all => "Test::Pod::Coverage 1.00 required for testing POD coverage" if $@;
all_pod_coverage_ok();
