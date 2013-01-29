#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-run_lane.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-run_lane.t $
#
use strict;
use warnings;
use Test::More tests => 7;
use t::util;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

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
