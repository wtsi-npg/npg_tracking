#########
# Author:        mg8
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $ $Author: mg8 $
# Id:            $Id: 11-npg_tracking-Schema.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/11-npg_tracking-Schema.t $
#

use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;


BEGIN{
  use_ok ( 'npg_tracking::Schema' );
}

