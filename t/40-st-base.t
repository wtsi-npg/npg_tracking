#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2008-04-28
# Last Modified: $Date: 2012-03-01 10:36:10 +0000 (Thu, 01 Mar 2012) $
# Id:            $Id: 40-st-base.t 15277 2012-03-01 10:36:10Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/40-st-base.t $
#

use strict;
use warnings;
use Test::More tests => 6;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 15277 $ =~ /(\d+)/mx; $r; };

use_ok('st::api::base');

{
  my $base = st::api::base->new();
  isa_ok($base, 'st::api::base');
  like($base->live_url(), qr/psd\-support/, 'live_url');
  like($base->dev_url(), qr/psd\-dev/, 'dev_url');
  is((scalar $base->fields()), undef, 'no default fields');
  is($base->primary_key(), undef, 'no default pk');
}

1;
