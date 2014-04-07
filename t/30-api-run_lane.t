use strict;
use warnings;
use Test::More tests => 30;

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/npg_api];

use_ok('npg::api::run_lane');

my $run_lane = npg::api::run_lane->new();
isa_ok($run_lane, 'npg::api::run_lane');

{
  my $run_lane = npg::api::run_lane->new({'id_run_lane' => 1500,});
  my $run = $run_lane->run();
  is($run->id_run(), 194);
  is($run_lane->position(), 8);
  is($run_lane->is_control(),  0, 'not a control');
  is($run_lane->is_pool(),  0, 'not a pool');
}

{
  my $run_lane = npg::api::run_lane->new({
            'id_run'   => 2888,
            'position' => 2,
           });
  is($run_lane->id_run_lane, 22657, 'lookup from id_run and position');
}

{
  my $run_lane = npg::api::run_lane->new({
            'id_run_lane' => 5,
           });
  my $run = $run_lane->run();
  is($run_lane->lims(), undef, 'no batch, no lims');
  is($run_lane->is_library(), 0, 'no batch, no library info');
  is($run_lane->is_control(), 0, 'no batch, no control info');
  is($run_lane->is_pool(), 0, 'no batch, no pool info');
  is($run_lane->manual_qc(), undef, 'no batch, manual qc undefined');
}

{
  my $run_lane = npg::api::run_lane->new({
            'id_run'   => 3948,
            'position' => 1,
           });
  is($run_lane->id_run_lane, 31136, 'lookup from id_run and position');
  ok(!$run_lane->contains_nonconsented_human, 'does not contain nonconsented human');
  ok(!$run_lane->contains_unconsented_human, 'does not contain unconsented human (back compat)');
  ok(!$run_lane->is_library, 'not a library');
  ok(!$run_lane->is_control, 'not a control');
  ok($run_lane->is_pool, 'is a pool');
  is($run_lane->asset_id, 65099,'correct asset id');
  is($run_lane->manual_qc, 'pass','passed manual_qc');
}

{
  my $run_lane = npg::api::run_lane->new({
            'id_run'   => 4231,
            'position' => 1,
           });
  ok(!$run_lane->is_spiked_phix(), 'run 4231 lane 1 is not spiked phix');
  is($run_lane->manual_qc, 'pass', 'manual qc passed');

  $run_lane = npg::api::run_lane->new({
            'id_run'   => 7056,
            'position' => 1,
           });
  ok($run_lane->is_spiked_phix(), 'run 7056 lane 1 is spiked phix');
  ok($run_lane->is_pool, 'is a pool');
  is($run_lane->manual_qc, undef, 'manual qc undefined');
}

{
  my $run_lane = npg::api::run_lane->new({
            'id_run'   => 4231,
            'position' => 4,
           });
  ok($run_lane->is_control, 'lane 4 is control');
}

{
  my $run_lane = npg::api::run_lane->new({
            'id_run'   => 883,
            'position' => 5,
           });
  ok($run_lane->is_library, 'is a library');
  is($run_lane->contains_nonconsented_human, 1, 'contains nonconsented human');
}

{
  my $run_lane = npg::api::run_lane->new({
            'id_run'   => 6936,
            'position' => 2,
           });
  ok($run_lane->is_pool, 'is a pool');
  ok($run_lane->contains_nonconsented_human, 'contains nonconsented human');
}

1;

