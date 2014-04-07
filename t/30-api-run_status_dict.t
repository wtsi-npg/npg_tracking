use strict;
use warnings;
use Test::More tests => 4;

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
