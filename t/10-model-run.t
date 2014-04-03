use strict;
use warnings;
use t::util;
use npg::model::instrument;
use npg::model::user;
use npg::model::annotation;
use Test::More tests => 125;
use Test::Exception;

use_ok('npg::model::run');

# using fixtures to import data
#
my $util  = t::util->new({
                fixtures  => 1,
            });
my $model = npg::model::run->new({
                util => $util
            });

########
# first tests are on model object that is not actually linked to a run
#
isa_ok($model, 'npg::model::run', '$model');
my @fields = $model->fields();
is((scalar @fields), 13, '$model->fields() size');

isa_ok( $model->potentially_stuck_runs(), q{HASH}, q{potentially_stuck_runs} );

my ($whole_v, $point_v) = $model->_parse_version('2.01');
is($whole_v, 2, 'correct whole version number for 2.01');
is($point_v, 1, 'correct point version number for 2.01');

($whole_v, $point_v) = $model->_parse_version('2');
is($whole_v, 2, 'correct whole version number for 2');
is($point_v, 0, 'correct point version number for 2');

($whole_v, $point_v) = $model->_parse_version('0.01');
is($whole_v, 0, 'correct whole version number for 0.01');
is($point_v, 1, 'correct point version number for 0.01');

throws_ok {($whole_v, $point_v) = $model->_parse_version('dfasdf');} qr{Given version number is not valid:}, 'no valid version given';

is($model->_cmp_version('2.01', '2.8'), -1, 'version 2.01 less than 2.8');
is($model->_cmp_version('2.10', '2.8'), 1, 'version 2.10 greater than 2.8');
is($model->_cmp_version('2.8', '2.8'), 0, 'version 2.8 equals to 2.8');

my $runs_on_batch = $model->runs_on_batch();
isa_ok($runs_on_batch, 'ARRAY', '$model->runs_on_batch()');
is(scalar@{$runs_on_batch}, 0, '$model->runs_on_batch() is empty');
$runs_on_batch = $model->runs_on_batch(10);
isa_ok($runs_on_batch, 'ARRAY', '$model->runs_on_batch(10)');
is($model->runs_on_batch(10), $runs_on_batch, '$model->runs_on_batch(10) cached ok');

my $runs = $model->runs();
isa_ok($runs, 'ARRAY', '$model->runs()');

my $run = $runs->[-1];
isa_ok($run, 'npg::model::run', 'last of $model->runs()');


my $name = $model;
is($name->name(), 'UNKNOWN_00000', 'unknown name if no instrument name and no id_run - default');

$model->instrument_format->model('HK');
is($name->name(), 'UNKNOWN_0000', 'unknown name if no instrument name and no id_run - HK model');

$model->{scs28} = 1;
is($name->name(), 'UNKNOWN_00000', 'unknown name if no instrument name and no id_run - HK model, scs28 mod');


is($model->attach_annotation('test annotation'), 1, '$model->attach_annotation() with annotation, but no $model->id_run()');
is($model->{annotations}->[0], 'test annotation', 'annotation appended to annotations array within $model');
is($model->id_user(), undef, 'id_user not found by model or current run status');

#########
#  now begin testing on model object which is a run, using first one obtained above
# (if runs are added to the fixtures the results can change, so use $got to
# make updating the tests a little easier)
{
   my $run2 = $runs->[1];
   my $got = $run2->id_run;
   is($got, 9950, 'correct id_run for the 2nd run');
   ok(!$run2->scs28(), "run $got not with scs 2.8 or above");
   is($run2->name(), 'HS1_09950', "correct run name for run $got");
   
   $run2 = $runs->[9];
   $got = $run2->id_run;
   is($got, 15, 'correct id_run for the 10th run');
   ok($run2->scs28(), "run $got with scs 2.8 or above");
   is($run2->name(), 'IL10_00015', "correct run name for run $got");
}

{
  my $runs_on_batch = $run->runs_on_batch();
  isnt($runs_on_batch->[0], undef, '$run->runs_on_batch() has found some runs');

  my $loader_info = $run->loader_info();
  isa_ok($loader_info, 'HASH', '$run->loader_info()');
  is($run->loader_info(), $loader_info, 'loader_info cached');
  is($loader_info->{loader}, 'joe_admin', 'loader name ok');
  is($loader_info->{date}, '2007-06-05', 'loading date ok');
  my $instrument = $run->instrument();
  isa_ok($instrument, 'npg::model::instrument', '$run->instrument()');
  $run->loader_info(1)->{date} = '2010-05-28 10:20:00';
  ok($run->scs28, 'this run is on instrument with scs 2.8');

  my $name = $run->name();
  is($name, 'IL1_00001', 'name generated ok from instrument name and id_run');
  my $run_folder = $run->run_folder();
  is($run_folder, '070605_IL1_00001', 'run_folder generated ok from loading date, instrument name and id_run');
  my $flowcell_id = $run->flowcell_id();
  is($flowcell_id, undef, 'flowcell_id is not defined');
  my $tags = $run->tags();
  isa_ok($tags, 'ARRAY', '$run->tags()');
  is($run->tags(), $tags, 'tags cached');
  isa_ok($tags->[0], 'npg::model::tag', '$tags->[0]');
  is($tags->[0]->tag(), '2G', 'tag is correct');
  is($run->end(), q{}, 'not paired');
  my $run_lanes = $run->run_lanes();
  isa_ok($run_lanes, 'ARRAY', '$run->run_lanes()');
  is($run->run_lanes(), $run_lanes, 'run_lanes cached');
  isa_ok($run_lanes->[0], 'npg::model::run_lane', '$run_lanes->[0]');
  my $current_run_status = $run->current_run_status();
  isa_ok($current_run_status, 'npg::model::run_status', '$run->current_run_status()');
  is($run->current_run_status(), $current_run_status, 'current_run_status cached');
  my $run_statuses  = $run->run_statuses();
  isa_ok($run_statuses, 'ARRAY', '$run->run_statuses()');
  is($run->run_statuses(), $run_statuses, 'run_statuses cached');
  isa_ok($run_statuses->[0], 'npg::model::run_status', '$run_statuses->[0]');
  my $run_annotations = $run->run_annotations();
  isa_ok($run_annotations, 'ARRAY', '$run->run_annotations()');
  is($run->run_annotations(), $run_annotations, 'run_annotations cached');
  isa_ok($run_annotations->[0], 'npg::model::run_annotation', '$run_annotations->[0]');
  my $annotations = $run->annotations();
  isa_ok($annotations, 'ARRAY', '$run->annotations()');
  is($run->annotations(), $annotations, 'annotations cached');
  isa_ok($annotations->[0], 'npg::model::annotation', '$annotations->[0]');

  throws_ok { $run->attach_annotation(); } qr{No\ annotation\ to\ save}, '$run->attach_annotation() with no annotation';

  $util->requestor('public');
  my $sub = sub {
    my $msg = shift;
    push @{$run->{emails}}, $msg->as_string;
    return;
  };
  MIME::Lite->send('sub',$sub);
  my $annotation = npg::model::annotation->new({util => $util, id_annotation => 1});
  is($run->attach_annotation($annotation), 1, 'attach_annotation successful');
  my $recent_runs = $run->recent_runs();
  isa_ok($recent_runs, 'ARRAY', '$run->recent_runs()');
  is($run->recent_runs(), $recent_runs, 'recent_runs cached');
  is($recent_runs->[0], undef, 'no recent runs');
  $run->{recent_runs} = undef;
  my $recent_mirrored_runs = $run->recent_mirrored_runs();
  isa_ok($recent_mirrored_runs, 'ARRAY', '$run->recent_mirrored_runs()');
  is($run->recent_mirrored_runs(), $recent_mirrored_runs, 'recent_mirrored_runs cached');
  is($recent_mirrored_runs->[0], undef, 'no recent mirrored runs');
  $run->{recent_mirrored_runs} = undef;
  $run->{'days'} = '4000';
  $recent_runs = $run->recent_runs();
  ok($recent_runs->[0], 'recent runs found');
  $recent_mirrored_runs = $run->recent_mirrored_runs();
  ok($recent_mirrored_runs->[0], 'recent mirrored runs found');

  my $recent_running_runs = $run->recent_running_runs();
  my $test_deeply = [
    { id_run => 1,  start => '2007-06-05 10:04:23', end => '', id_instrument => 3, },
    { id_run => 5,  start => '2007-06-05 12:31:44', end => '2007-06-05 12:32:28', id_instrument => 3, },
    { id_run => 95, start => '2007-06-05 10:04:23', end => '2007-06-05 11:16:55', id_instrument => 4, },
  ];
  $recent_running_runs->[0]->{end} = q{};
  is_deeply($recent_running_runs, $test_deeply, 'returned data structure is correct');

  is($run->id_user(), 1, '$run->id_user() got from current run status');
  is($run->id_user(5), 5, 'id_user set by $run->id_user(5)');
  is($run->id_user(), 5, 'id_user got from internal cache as set');
  $util->requestor('joe_annotator');
  $tags = [qw(good sorted)];

  lives_ok { $run->save_tags($tags, $util->requestor()) } 'tags saved fine';
  lives_ok { $run->remove_tags(['good'], $util->requestor()) } 'tags removed fine';
}

{
  my $run = npg::model::run->new({
          util        => $util,
          id_run_pair => 0,
          is_paired   => 1,
         });
  is($run->end(), 1, 'PE first end=1');

  $run = npg::model::run->new({
          util        => $util,
          id_run_pair => 1,
          is_paired   => 1,
         });
  is($run->end(), 2, 'PE second end=2');
}

{
  my $model = npg::model::run->new({
    util => $util,
    name => 'IL1_0007',
  });
  is($model->id_run(), 7, 'model initialised ok by run name, no id_run given');

  $model = npg::model::run->new({
    util => $util,
    name => 'HS1_0007',
  });
  is($model->id_run(), 7, 'model initialised ok by run name, no id_run given');
}

{
  my $model = npg::model::run->new({
            util                 => $util,
            batch_id             => 939,
            id_instrument        => 3,
            expected_cycle_count => 35,
            priority             => 1,
            is_paired            => 1,
            team                 => 'RAD',
            id_user              => $util->requestor->id_user(),
            flowcell_id          => '619MJAAXX'
           });
  $model->{'run_lanes'} = [];

  for my $position (1..8) {
    my $rl = npg::model::run_lane->new({
          util         => $util,
          tile_count   => 300,
          tracks       => 3,
          projectname  => 'SLX_TEST',
          position     => $position,
               });
    push @{$model->{run_lanes}}, $rl;
  }

  ok($model->create(), 'created run ok - is_paired without id_run_pair, or declared actual_cycle_count');
}

{
  my $model = npg::model::run->new({
            util                 => $util,
            batch_id             => 939,
            id_instrument        => 3,
            expected_cycle_count => 35,
            actual_cycle_count   => 10,
            priority             => 1,
            id_run_pair          => 3,
            is_paired            => 1,
            team                 => 'RAD',
            id_user              => $util->requestor->id_user(),
            paired_read          => 'paired_read',
           });
  my $annotation = npg::model::run_annotation->new({util => $util, id_annotation => 1});
  $model->{annotations} = [$annotation];

  lives_ok { $model->create(); } 'created run ok - is_paired with id_run_pair and declared actual_cycle_count';

  ok($model->has_tag_with_value('paired_read'), 'run has paired_read tag');
  ok(!$model->has_tag_with_value('multiplex'), 'run has no multiplex tag');
}

{
  my $model = npg::model::run->new({
				    util                 => $util,
				    id_instrument        => 3,
				    expected_cycle_count => 35,
				    priority             => 1,
				    team                 => 'joint',
				    id_user              => $util->requestor->id_user(),
				   });
  lives_ok { $model->create(); } 'Unpaired run created without supplying batch_id explicitly';
  is($model->batch_id(), 0, 'batch_id 0 if not set explicitly');

  $model = npg::model::run->new({
				    util                 => $util,
				    id_instrument        => 3,
				    expected_cycle_count => 35,
				    priority             => 1,
				    team                 => 'joint',
				    id_user              => $util->requestor->id_user(),
                                    batch_id             => undef,
				});
  lives_ok { $model->create(); } 'Unpaired run created supplying undef batch_id explicitly';
  is($model->batch_id(), 0, 'batch_id 0 if provided as undef');
  is($model->id_run_pair, undef, 'id_run_pair is undef is not supplied');

  $model = npg::model::run->new({
				    util                 => $util,
				    id_instrument        => 3,
				    expected_cycle_count => 35,
				    priority             => 1,
				    team                 => 'joint',
				    id_user              => $util->requestor->id_user(),
				    batch_id             => q{},
				});
  lives_ok { $model->create(); } 'Unpaired run created supplying an empty string batch_id explicitly';
  is($model->batch_id(), 0, 'batch_id 0 if provided as an empty string');
}

{
  my $model = npg::model::run->new({
				    util                 => $util,
				    batch_id             => 939,
				    id_instrument        => 3,
				    expected_cycle_count => 35,
				    priority             => 1,
				    team                 => 'joint',
				    id_user              => $util->requestor->id_user(),
				   });
  lives_ok { $model->create(); } 'created run ok - not paired';
}

{
  $util->requestor('joe_loader');

  my $run1 = npg::model::run->new({
           util                 => $util,
           batch_id             => 939,
           id_instrument        => 3,
           expected_cycle_count => 35,
           priority             => 1,
           team                 => 'A',
           id_user              => $util->requestor->id_user(),
          });
  $run1->create();

  my $run2 = npg::model::run->new({
           util                 => $util,
           id_run_pair          => $run1->id_run(),
           batch_id             => 939,
           id_instrument        => 3,
           expected_cycle_count => 35,
           priority             => 1,
           team                 => 'B',
           id_user              => $util->requestor->id_user(),
          });
  $run2->create();

  my $cancelled = npg::model::run_status_dict->new({
                util        => $util,
                description => 'run cancelled',
               });
  my $rs2 = npg::model::run_status->new({
           util               => $util,
           id_run             => $run2->id_run(),
           id_run_status_dict => $cancelled->id_run_status_dict(),
           iscurrent          => 1,
           id_user            => $util->requestor->id_user(),
          });
  $rs2->create();

  is($run1->run_pair, undef, 'run paired with cancelled run');

  my $run3 = npg::model::run->new({
           util                 => $util,
           id_run_pair          => $run1->id_run(),
           batch_id             => 939,
           id_instrument        => 3,
           expected_cycle_count => 35,
           priority             => 1,
           team                 => 'C',
           id_user              => $util->requestor->id_user(),
          });
  $run3->create();

  is($run1->run_pair->id_run(), $run3->id_run(), 'run paired with non-cancelled run');
}

{
  my $run = npg::model::run->new({
          util   => $util,
          id_run => 700,
         });
  cmp_ok($run->flowcell_id, 'eq', '619MJAAXX', 'flowcell_id');

  my $run_lanes = $run->run_lanes();
  is((scalar @{$run_lanes}), 8, 'number of lanes for run');
}

{
  my $run = npg::model::run->new({
          util   => $util,
          id_run => 6,
         });
  is($run->is_paired_read(), 1, 'run 6 is paired read based on tag information');

  $run = npg::model::run->new({
          util   => $util,
          id_run => 7,
         });
  is($run->is_paired_read(), 0, 'run 7 is paired read based on tag information');
  ok(!$run->is_in_staging ,'run 7 is not in staging');
  ok(!$run->has_tag_with_value('rta') ,'run 7 does not have an rta tag');

  $run = npg::model::run->new({
          util   => $util,
          id_run => 8,
         });
  is($run->is_paired_read(), undef, 'run 8 is paired read or not, unknown based on tag information');
  ok($run->is_in_staging ,'run 8 is in staging');
  ok($run->has_tag_with_value('rta') ,'run 8 does have an rta tag');

 $run = npg::model::run->new({
          util   => $util,
          id_run => 9,
          is_paired =>1,
         });
  is($run->is_paired_read(), 1, 'run 9 is paired run so it is paired read as well');
}

lives_ok {$util->fixtures_path(q[t/data/fixtures]); $util->load_fixtures;} 'a new set of fixtures loaded';

{
  my $model = npg::model::run->new({
            util                 => $util,
            batch_id             => 939,
            id_instrument        => 64,
            expected_cycle_count => 35,
            actual_cycle_count   => 10,
            priority             => 1,
            is_paired            => 1,
            team                 => 'RAD',
            id_user              => $util->requestor->id_user(),
            fc_slot              => 'fc_slotA',
           });
  lives_ok { $model->create(); } 'created run ok - fc_slotA tag passed';
  ok($model->has_tag_with_value('fc_slotA'), 'run has fc_slotA tag');
  cmp_ok($model->run_folder, 'eq', DateTime->now()->strftime(q(%y%m%d)).'_HS3_09952_A', 'HiSeq run folder');
}

{
  my $model = npg::model::run->new({
            util                 => $util,
            batch_id             => 939,
            id_instrument        => 64,
            expected_cycle_count => 35,
            actual_cycle_count   => 10,
            priority             => 1,
            id_run_pair          => 3,
            is_paired            => 1,
            team                 => 'RAD',
            id_user              => $util->requestor->id_user(),
            fc_slot              => 'fc_slotB',
            flowcell_id          => '20353ABXX',
           });
  lives_ok { $model->create(); } 'created run ok - fc_slotB tag passed';
  ok($model->has_tag_with_value('fc_slotB'), 'run has fc_slotB tag');
  cmp_ok($model->run_folder, 'eq', DateTime->now()->strftime(q(%y%m%d)).'_HS3_09953_B_20353ABXX', 'HiSeq run folder');
}

{
  my $model = npg::model::run->new({
            util                 => $util,
            batch_id             => 939,
            id_instrument        => 64,
            expected_cycle_count => 35,
            actual_cycle_count   => 10,
            priority             => 1,
            is_paired            => 0,
            team                 => 'RAD',
            id_user              => $util->requestor->id_user(),
            fc_slot              => 'fc_slotB',
            flowcell_id          => '20353ABXX',
            folder_name          => '110401_HS3_B939_B_20353ABXX',
            folder_path_glob     => '/{export,nfs}/sf40/ILorHSany_sf40/*/',
           });
  lives_ok { $model->create(); } 'created run ok - folder name and glob passed';
  cmp_ok($model->folder_name, 'eq', '110401_HS3_B939_B_20353ABXX', 'folder name set');
  cmp_ok($model->run_folder, 'eq', '110401_HS3_B939_B_20353ABXX', 'run folder overrided');
  cmp_ok($model->folder_path_glob, 'eq', '/{export,nfs}/sf40/ILorHSany_sf40/*/', 'folder path glob set');
}

{
  my $m = npg::model::run->new({util => $util,});
  is(join(q[ ], $m->teams), 'A B C RAD joint', 'ordered list of teams');
  ok(!$m->validate_team(), 'team validation failed if no arg supplied');
  ok(!$m->validate_team('dodo'), 'team validation failed for non-existing team');
  ok($m->validate_team('B'), 'team B validation succeeds');
  ok(!$m->is_dev(), 'id_dev is false for a model without a defined run');

  $m = npg::model::run->new({util => $util, id_run => 9950,});
  is($m->team, 'joint', 'team is joint');
  ok(!$m->is_dev, 'not a dev run');

  $m = npg::model::run->new({util => $util, id_run => 1,});
  is($m->team, 'RAD', 'team is RAD');
  ok($m->is_dev, 'dev run');
}

1;

