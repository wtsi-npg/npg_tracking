#########
# Author:        rmp
# Created:       2007-10
# copied from: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/30-api-run.t, r15308
#
use strict;
use warnings;
use Test::More tests => 49;
use Test::Exception;
use t::useragent;
use npg::api::util;

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/npg_api];

use_ok('npg::api::run');
my $base_url = $npg::api::util::LIVE_BASE_URI;

my $run1 = npg::api::run->new();
isa_ok($run1, 'npg::api::run', 'constructs ok');
is($run1->id_run(), 0, 'id is zero without constructor args');

my $run2 = npg::api::run->new({'id_run'=>1});
isa_ok($run2, 'npg::api::run', 'constructs ok with args');
is($run2->id_run(), 1, 'yields id from constructor ok');

my $run3 = npg::api::run->new({'id_run'=>'IL45_0456'});
is($run3->id_run(), 456, 'yields id from name');

my $run4 = npg::api::run->new({
			       'id_run'      => 457,
			       'id_run_pair' => $run3->id_run(),
			       'run_pair'    => $run3,
			      });
my $run_pair = $run4->run_pair();
is($run3, $run_pair);

is($run3->id_run(999), 999);


{
  my $run  = npg::api::run->new({'id_run' => 2888,});
  my $tags = $run->tags();
  is(scalar @{$tags}, 2, 'correct number of tags for run 2888');
  is($tags->[0], 'rta', 'correct first tag');
}

{
  my $run  = npg::api::run->new({'id_run' => 1104,});
  is($run->is_paired_run(), 0, 'run 1104 is not paired run');
  is($run->is_paired_read(), 0, 'run 1104 is not paired read');
  is($run->is_single_read(), 1, 'run 1104 is single read');
  is($run->team(), 'joint', 'team is joint');
}

{
  my $run  = npg::api::run->new({'id_run' => 1,});
  is($run->is_paired_run(), 0, 'run 1 is paired run');
  is($run->is_paired_read(), 0, 'run 1 is paired read');
  is($run->is_single_read(), 1, 'run 1 is not single read');
}

{
  my $run  = npg::api::run->new({'id_run' => 2888,});
  is($run->is_paired_run(), 0, 'run 2888 is not paired run');
  is($run->is_paired_read(), 0, 'run 2888 is not paired read');
  is($run->is_single_read(), 1, 'run 2888 is single read');
  ok($run->having_control_lane(), 'run 2888 having control lane');
}

{
  my $run  = npg::api::run->new({'id_run' => 2,});
  is($run->is_paired_run(), 0, 'run 2 is not paired run');
  throws_ok { $run->is_paired_read(); } qr{No data on paired/single read available yet}, 'no tag information available for run 2';
  throws_ok { $run->is_single_read(); } qr{No data on paired/single read available yet}, 'no tag information available for run 2 when call is_single_read';
}

{
  my $run  = npg::api::run->new({'id_run' => 1,});

  my $run_lanes = $run->run_lanes();
  is(scalar @{$run_lanes}, 8, 'unprimed cache run_lanes');

  is($run->current_run_status->id_run_status(), 57799);

  my $run_annotations = $run->run_annotations();
  is(scalar @{$run_annotations}, 5);
  is($run_annotations->[0]->id_run_annotation(),665);

  my $recent = $run->list_recent();
  is(scalar @{$recent}, 128);
}

{
  my $run  = npg::api::run->new({
				 'id_run' => 'IL99_FOO',
				});
  is($run->id_run(), 0, 'bad run by name ok');
}

{
  my $run  = npg::api::run->new({
				 id_run => 1104,
				});
  my $instrument = $run->instrument();
  isa_ok($instrument, 'npg::api::instrument', 'run->instrument');
  is($instrument->name(), 'IL9');
}

{ 
  my $run  = npg::api::run->new({id_run => 4209,});
  ok(!$run->having_control_lane(), 'run 4209 not having control lane');
  is($run->run_folder, '091218_IL28_4209', 'correct run_folder returned');
}

{
  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/npg_api_run];
  my $run  = npg::api::run->new({id_run => 604,});
  isa_ok($run->run_pair(), 'npg::api::run', 'run_pair is run object');
  is($run->run_pair()->id_run(), 636, 'its id_run is 636');
  is($run->run_pair()->batch_id(), $run->batch_id(), 'batch id the same within run pair');

  $run  = npg::api::run->new({id_run => 636,});
  isa_ok($run->run_pair(), 'npg::api::run', 'run_pair is run object');
  is($run->run_pair()->id_run(), 604, 'its id_run is 604');

  my $lims;
  isa_ok($lims = $run->lims(), 'st::api::lims', 'lims accessor returns st::api::lims object');
  is($lims->batch_id, 1001, 'lims object batch id is set correctly');
  is($lims->id_run, 636, 'lims object id_run is set correctly');

  $lims = $run->run_pair->lims();
  is($lims->batch_id, 1001, 'run_pair lims object batch id is set correctly');
  is($lims->id_run, 604, 'run_pair lims object id_run is set correctly');
}

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[];
{
  my $ua   = t::useragent->new({
    is_success => 1,
    mock => { $base_url.q{/run/recent/running/runs.xml} => q{t/data/rendered/run/recent/running/runs_4000_days.xml} },
			       });
  my $run  = npg::api::run->new({
				 util   => npg::api::util->new({useragent => $ua,}),
				});

  my $runs;
  lives_ok { $runs = $run->recent_running_runs(); } 'no croak on recent_running_runs';
  is(scalar@{$runs}, 3, '3 recent runs returned');
  my $test_deeply = [
    { id_run =>  1, start => '2007-06-05 10:04:23', end => '2009-01-29 14:09:31', id_instrument => 3},
    { id_run =>  5, start => '2007-06-05 12:31:44', end => '2007-06-05 12:32:28', id_instrument => 3},
    { id_run => 95, start => '2007-06-05 10:04:23', end => '2007-06-05 11:16:55', id_instrument => 4},
  ];
  is_deeply($runs, $test_deeply, 'returned data structure is correct');
}

{
  my $ua   = t::useragent->new({
    is_success => 1,
    mock => {
    $base_url.q{/run/2888;update_tags} => q{Run 2888 tagged},
    $base_url.q{/run/2888} => q{t/data/npg_api/npg/run/2888.xml},
            },
			      });
  my $run  = npg::api::run->new({
				 util   => npg::api::util->new({useragent => $ua,}),
				 id_run => 2888,
				});
  lives_ok { $run->add_tags('rta', 'paired_read', 'staging'); } 'no croak when adding new tags rta, paired_read and staging';
}

{
  my $ua   = t::useragent->new({
    is_success => 1,
    mock => { 
    $base_url.q{/run/2888;update_tags} => q{Run 2888 tagged},
    $base_url.q{/run/2888} => q{t/data/npg_api/npg/run/2888.xml}, 
            },
			      });
  my $run  = npg::api::run->new({
				 util   => npg::api::util->new({useragent => $ua,}),
				 id_run => 2888,
				});
  lives_ok { $run->remove_tags('staging'); } 'no croak when removing rta and staging';
}

1;

