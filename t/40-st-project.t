#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-01-18
# Last Modified: $Date: 2011-08-17 14:40:33 +0100 (Wed, 17 Aug 2011) $
# Id:            $Id: 40-st-project.t 13925 2011-08-17 13:40:33Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/40-st-project.t $
#
use strict;
use warnings;
use Test::More tests => 6;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 13925 $ =~ /(\d+)/mx; $r; };

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/st_api_lims_new';

use_ok('st::api::project');

{
  my $project = st::api::project->new();
  isa_ok($project, 'st::api::project');
  is($project->project_cost_code(), undef, 'no project code returned with no data');
}

{
  my $project = st::api::project->new({id => 429,});
  is ($project->id, 429, 'project id');
  is ($project->name, '3C and HiC of Plasmodium falciparum IT', 'project name');
  is ($project->project_cost_code, 'S0701', 'project cost code');
}

1;
