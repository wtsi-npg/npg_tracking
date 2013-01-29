#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2008-04-28
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-usage.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-usage.t $
#

use strict;
use warnings;
use Test::More tests => 3;
use t::util;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 14928 $ =~ /(\d+)/mx; $r; };

use_ok('npg::model::usage');

my $util = t::util->new({
			 fixtures => 1,
			});

{
  my $usage = npg::model::usage->new({
				      util => $util,
				     });
  isa_ok($usage, 'npg::model::usage');
  is_deeply($usage->current_repositories(), [], 'current_repositories');
}
