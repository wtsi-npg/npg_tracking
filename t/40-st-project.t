use strict;
use warnings;
use Test::More tests => 6;

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
