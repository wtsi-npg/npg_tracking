#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       June 2010
# Last Modified: $Date: 2010-10-08 11:35:43 +0100 (Fri, 08 Oct 2010) $
# Id:            $Id: 10-sequence-reference.t 11267 2010-10-08 10:35:43Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/useful_modules/branches/prerelease-29.0/t/10-sequence-reference.t $
#

package reference;

use strict;
use warnings;
use Test::More tests => 2;

use_ok('npg_tracking::data::reference::info');

{
  my $ruser = npg_tracking::data::reference::info->new();
  isa_ok($ruser, 'npg_tracking::data::reference::info');
}
