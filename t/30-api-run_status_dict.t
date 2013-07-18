#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-03-01 10:36:10 +0000 (Thu, 01 Mar 2012) $
# Id:            $Id: 30-api-run_status_dict.t 15277 2012-03-01 10:36:10Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/30-api-run_status_dict.t $
#
use strict;
use warnings;
use Test::More tests => 4;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 15277 $ =~ /(\d+)/mx; $r; };

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/npg_api';

use_ok('npg::api::run_status_dict');

my $rsd = npg::api::run_status_dict->new();
isa_ok($rsd, 'npg::api::run_status_dict');

{
  my $rsd  = npg::api::run_status_dict->new({'id_run_status_dict' => 5,});
  my $rsds = $rsd->run_status_dicts();
  is(scalar @{$rsds}, 24);
  my $runs = $rsd->runs();
  is(scalar @{$runs}, 2);
}

1;
