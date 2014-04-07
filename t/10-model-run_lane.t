use strict;
use warnings;
use Test::More tests => 7;
use t::util;

use_ok('npg::model::run_lane');

my $util = t::util->new({
       fixtures  => 1,
      });

{
  my $rl = npg::model::run_lane->new({
           util => $util,
          });
  isa_ok($rl, 'npg::model::run_lane', 'isa ok');
}

{
  my $rl = npg::model::run_lane->new({
           util         => $util,
           id_run       => 1,
           tile_count   => 100,
           tracks       => 2,
           position     => 9,
          });
  ok($rl->create(), 'create');
  $rl->delete;
}

{
  my $rl = npg::model::run_lane->new({
           util        => $util,
           id_run_lane => 1,
          });
  my $a = $rl->annotations();
  isa_ok($a, 'ARRAY');
  is((scalar @{$a}), 3, 'annotations for run_lane 1');

  my $rla = $rl->run_lane_annotations();
  isa_ok($rla, 'ARRAY');
  is((scalar @{$rla}), 3, 'run_lane_annotations for run_lane 1');
}

1;
