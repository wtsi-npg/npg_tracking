use strict;
use warnings;
use Test::More tests => 126;
use Test::Deep;
use Test::Exception;

use t::util;

my $util = t::util->new({ fixtures => 1 });

use_ok('npg::model::instrument');

{
  my $model = npg::model::instrument->new({
             util => $util,
            });

  isa_ok($model, 'npg::model::instrument', '$model');
  my @fields = $model->fields();
  is($fields[0], 'id_instrument', 'first of $model->fields() array is id_instrument');

  my $instruments = $model->instruments();
  isa_ok($instruments, 'ARRAY', '$model->instruments()');
  isa_ok($instruments->[0], 'npg::model::instrument', '$model->instruments()->[0]');

  my $current_instruments = $model->current_instruments();
  isa_ok($current_instruments, 'ARRAY', '$model->current_instruments()');
  is((scalar@{$current_instruments} + 1), scalar@{$instruments}, 'scalar@{$model->current_instruments()} is 1 less than scalar@{$model->instruments()}');
  is($model->current_instruments(), $current_instruments, '$model->current_instruments() cached ok');
  is($model->manufacturer_name, undef,
    'manufacturer name is undefined for a model used in list context');
}

{
  my $model = npg::model::instrument->new({
             util => $util,
             name => 'IL1',
            });
  isa_ok($model, 'npg::model::instrument', '$model with name predeclared');
  is($model->id_instrument(), 3, 'id_instrument correct');

  $model = npg::model::instrument->new({
    util          => $util,
    name          => 'IL3',
    id_instrument => 6,
  });
  isa_ok($model, 'npg::model::instrument', '$model with name and id_instrument predeclared');
  is($model->external_name(), 'eas92', 'external name correct');
}

{
  my $model = npg::model::instrument->new({
             util          => $util,
             id_instrument => 4,
            });
  my $current_run = $model->current_run();
  isa_ok($current_run, 'npg::model::run', '$model->current_run()');
  is($model->current_run(), $current_run, '$model->current_run() cached ok');
  is($model->model(), 'HK', '$model->model() retrieved correctly');
  is($model->manufacturer_name(), 'Illumina', 'correct manufacturer name');

  my @desigs;
  foreach my $i ( @{$model->designations()} ) {
      push @desigs, $i->{description};
  }
  cmp_bag( \@desigs, ['R&D'], 'designation' );

  my $instrument_statuses = $model->instrument_statuses();
  isa_ok($instrument_statuses, 'ARRAY', '$model->instrument_statuses()');
  isa_ok($instrument_statuses->[0], 'npg::model::instrument_status', 'model->instrument_statuses()->[0]');

  my $instrument_mods = $model->instrument_mods();
  isa_ok($instrument_mods, 'ARRAY', '$model->instrument_mods()');
  is($model->instrument_mods(), $instrument_mods, '$model->instrument_mods() cached ok');
  isa_ok($instrument_mods->[0], 'npg::model::instrument_mod', '$model->instrument_mods()->[0]');

  my $current_instrument_mods = $model->current_instrument_mods();
  isa_ok($current_instrument_mods, 'HASH', '$model->current_instrument_mods()');
  is($model->current_instrument_mods(), $current_instrument_mods, '$model->current_instrument_mods() cached ok');
  is(keys%{$current_instrument_mods}, 1, '1 key found for $model->current_instrument_mods()');

  my $current_instrument_status = $model->current_instrument_status();
  isa_ok($current_instrument_status, 'npg::model::instrument_status', q{$model->current_instrument_status()});

  is($model->current_instrument_status->instrument_status_dict->description, 'up', 'current status is up');

  my $expected_next = {
           '4' => {'wash required' => '3'},
           '1' => {'planned service' => '9'},
           '3' => {'down for repair' => '8'},
           '2' => {'planned repair' => '7'},
           '5' => {'wash in progress' => '11'},
         };
  cmp_deeply ($model->possible_next_statuses, $expected_next, 'expected next statuses');

  my $run_status = 'run complete';
  my $auto_status = 'wash required';
  is($model->status_to_change_to($run_status), 'wash required',
      qq["up" should be changed to "$auto_status", "$run_status" run status given]);
  is($model->current_instrument_status->instrument_status_dict->description, 'up',
      'current status is still up');
  ok(!$model->status_to_change_to(), 'no need to change "up" status, no run status given');
  throws_ok {$model->autochange_status_if_needed() } qr/Run status needed/,
    'error if run status is not given';
  $model->autochange_status_if_needed($run_status);
  is($model->current_instrument_status->instrument_status_dict->description, $auto_status,
      qq[status changed automatically to "$auto_status"]);
}

{
  my $instr = npg::model::instrument->new({
    util          => $util,
    name          => 'IL29',
  });
  isa_ok($instr, 'npg::model::instrument');
  is( $instr->instrument_comp(), 'il29win', 'instrument computer correct' );
  is( $instr->mirroring_host(), 'sf-1-1-01', 'mirroring host correct' );
  is( $instr->staging_dir(), '/staging/IL29/incoming', 'staging directory correct' );

  my @desigs;
  foreach my $i ( @{$instr->designations()} ) {
      push @desigs, $i->{description};
  }

  cmp_bag( \@desigs, ['Hot spare', 'R&D'], 'deal with multiple designations' );
}

{
  my $model = npg::model::instrument->new({
             util          => $util,
             id_instrument => 7,
            });
  ok(!$model->status_to_change_to(), 'no need to auto change status, as status is down');
}

{
  my $model = npg::model::instrument->new({
             util          => $util,
             id_instrument => 48,
            });
  is( $model->instrument_format->model(), 'cBot', 'cbot instrument model');
  is( $model->latest_contact(), '2010-05-11 13:34:04',
      'Read latest_contact field' );

  is( $model->percent_complete(), 40, 'Read percent_complete field' );
  is( $model->current_instrument_status->instrument_status_dict()->description(),
    'up', 'cbot current status is up');
  ok(!$model->status_to_change_to(), 'no need for an automatic status change' );
  lives_ok {$model->status_reset('wash required')} 'no error changing status';
  is( $model->current_instrument_status->instrument_status_dict()->description(),
    'wash required', 'cbot current status is wash required');
  lives_ok {$model->status_reset('wash performed')} 'no error moving from "wash required" directly to "wash performed"';
  lives_ok {$model->status_reset('wash in progress')} 'no error changing status';
  lives_ok {$model->status_reset('wash performed')} 'no error changing status';
  is( $model->current_instrument_status->instrument_status_dict()->description(),
    'up', 'cbot current status is up');
}

$util = t::util->new({fixtures=>1});
lives_ok {$util->fixtures_path(q[t/data/fixtures]); $util->load_fixtures;} 'a fresh set of fixtures loaded';
{
  my $model = npg::model::instrument->new({util => $util, id_instrument => 48,});
  is ($model->current_run->id_run, 9948, 'current run');
  is ($model->current_runs->[0]->id_run, 9948, 'current runs');
}

{
  my $model = npg::model::instrument->new({util => $util, id_instrument => 35,});
  is ($model->current_run->id_run, 9950, 'current run');
  is (scalar @{$model->current_runs}, 2, 'two current runs');
  is ($model->current_runs->[0]->id_run, 9950, 'first current run');
  is ($model->current_runs->[1]->id_run, 9949, 'second current run');
}

{
  for my $id ((48, 93)) {
    my $model = npg::model::instrument->new({util => $util, id_instrument => $id,});
    ok(!$model->does_sequencing, 'instrument does not do sequencing');
    ok(!$model->is_two_slot_instrument, 'is not two slot instrument');
    ok($model->is_cbot_instrument, 'is cbot instrument');
    if ($id == 48) {
      ok (!$model->is_idle, 'instrument is not idle');
    } else {
      ok ($model->is_idle, 'instrument is idle'); 
    }
    ok (!$model->status_to_change_to, 'no status to change to');
    ok (!$model->autochange_status_if_needed, 'no autochange status for cbot');
    is($model->fc_slots2current_runs, undef, 'does not have mapping of slots to current runs');
    is($model->fc_slots2blocking_runs, undef, 'does not have mapping of slots to blocking runs')
  }
}

{
  my $model = npg::model::instrument->new({util => $util, id_instrument => 34,});
  ok($model->does_sequencing, 'instrument does sequencing');
  ok(!$model->is_two_slot_instrument, 'is not two slot instrument');
  is($model->fc_slots2current_runs, undef, 'does not have mapping of slots to current runs');
  is($model->fc_slots2blocking_runs, undef, 'does not have mapping of slots to blocking runs');
  ok ($model->is_idle, 'instrument is idle');
  ok (!$model->status_to_change_to('analysis in progress'), 'no status to change to');
  ok (!$model->autochange_status_if_needed('analysis in progress'), 'no autochange status');
  throws_ok { $model->status_reset() } qr/Status to change to should be defined/, 'error when status to set to not given';
}

{
  my $instrument = npg::model::instrument->new({util => $util, id_instrument => 94,});
  is($instrument->name, 'NVX1', 'instrument name is correct');
  is($instrument->instrument_format->model, 'NovaSeqX', 'instrument model is correct'); 
  ok($instrument->does_sequencing, 'instrument does sequencing');
  ok($instrument->is_two_slot_instrument, 'is two slot instrument');
  ok(!$instrument->is_cbot_instrument, 'is not a cBot instrument');
  my $expected = {fc_slotA => [], fc_slotB => [],};
  cmp_deeply($instrument->fc_slots2current_runs, $expected, 'empty mapping of slots to current runs');
  cmp_deeply($instrument->fc_slots2blocking_runs, $expected, 'empty mapping of slots to blocking runs');
  ok ($instrument->is_idle, 'instrument is idle');
}

{
  my $model = npg::model::instrument->new({util => $util, id_instrument => 35,});
  ok($model->does_sequencing, 'instrument does sequencing');
  ok($model->is_two_slot_instrument, 'is two_slot instrument');
  my $expected = {fc_slotA => [], fc_slotB => [],};
  cmp_deeply($model->fc_slots2current_runs, $expected, 'empty mapping of slots to current runs');
  cmp_deeply($model->fc_slots2blocking_runs, $expected, 'empty mapping of slots to blocking runs');
  ok (!$model->is_idle, 'instrument is not idle');
  ok (!$model->status_to_change_to('analysis in progress'), 'no status to change to');
  ok (!$model->autochange_status_if_needed('analysis in progress'), 'no autochange status');
}

{
  my $model = npg::model::instrument->new({util => $util, id_instrument => 36,});
  ok($model->is_two_slot_instrument, 'is two_slot instrument');
  my $run = $model->current_runs->[0];
  is ($run->id_run, 9951, 'first current run');

  lives_ok { $run->save_tags(['fc_slotA']) } 'fc_slotA tag added';
  my $expected = {fc_slotA => [9951], fc_slotB => [],};
  cmp_deeply($model->fc_slots2current_runs, $expected, 'non-empty mapping of slotA to runs');
  ok (!$model->is_idle, 'instrument is not idle');
  ok (!$model->status_to_change_to, 'no status to change to');
}

{
  my $model = npg::model::instrument->new({util => $util, id_instrument => 36,});
  my $run = $model->current_runs->[0];
  lives_ok { $run->save_tags(['fc_slotB']) } 'fc_slotB tag added';
  my $expected = {fc_slotA => [9951], fc_slotB=> [9951],};
  cmp_deeply($model->fc_slots2current_runs, $expected, 'non-empty mapping of both slots to current runs');
  cmp_deeply($model->fc_slots2blocking_runs, {fc_slotA => [], fc_slotB => [],}, 'empty mapping of both slots to blocking runs');
}

{
  my $run = npg::model::run->new({util => $util, id_run => 9950,});
  $run->id_instrument(36);
  $run->save();
  lives_ok { $run->save_tags(['fc_slotA']) } 'fc_slotA tag saved';

  my $model = npg::model::instrument->new({util => $util, id_instrument => 36,});

  my $expected = {fc_slotA => [9950, 9951], fc_slotB=> [9951],};
  my $fc_slots2current_runs = $model->fc_slots2current_runs();
  @{ $fc_slots2current_runs->{fc_slotA} } = sort @{ $fc_slots2current_runs->{fc_slotA} };

  cmp_deeply($fc_slots2current_runs, $expected, 'non-empty mapping of both slots to current runs');
  cmp_deeply($model->fc_slots2blocking_runs, {fc_slotA => [], fc_slotB => [],}, 'empty mapping of both slots to blocking runs');
}

{
  my $run = npg::model::run->new({util => $util, id_run => 9950,});
  $run->id_instrument(36);
  $run->save();

  my $model = npg::model::instrument->new({util => $util, id_instrument => 36,});

  ok (!$model->current_run_by_id(22), 'undef returned for non-existing current run');
  $run = $model->current_run_by_id(9950);
  is(ref $run, 'npg::model::run', 'run object returned for an existing current run');
  is($run->id_run, 9950, 'returned run object has correct id_run');
}

{
  my $dbh = $util->dbh;
  my $update = q[update run_status set id_run_status_dict=2 where id_run=9951 and iscurrent=1];
  ok($dbh->do($update), 'run status updated');
  $dbh->commit;
  $dbh->disconnect;

  my $model = npg::model::instrument->new({util => $util, id_instrument => 36,});
  cmp_deeply($model->fc_slots2blocking_runs, {fc_slotA => [9951], fc_slotB => [9951],}, 'correct mapping of slots to blocking runs');
}

{
  my $model = npg::model::instrument->new({
    util => $util,
    id_instrument => 5,
  });
  my $next_up = q[planned service,planned repair,down for repair,wash required,wash in progress];
  is(join(q[,], @{npg::model::instrument::possible_next_statuses4status('up')}),
    $next_up, 'possible_next_statuses for "up" called as module function');
  is(join(q[,], @{$model->possible_next_statuses4status('up')}),
    $next_up, 'possible_next_statuses for "up" called as an object method');
  throws_ok {npg::model::instrument::possible_next_statuses4status()}
    qr/Current status should be given/, 'error if current status is not given';
  throws_ok {npg::model::instrument::possible_next_statuses4status('some status')}
    qr/Status 'some status' is nor registered in the status graph/,
    'error if current status is not recognised';

  $model = npg::model::instrument->new({
    util => $util,
    id_instrument => 11,
  });
  is(join(q[,], @{$model->possible_next_statuses4status('wash in progress')}),
    'wash performed,planned repair,planned service,down for repair', 
    'possible_next_statuses for "wash in progress" called as an object method');
}

{
  my $model = npg::model::instrument->new({
             util          => $util,
             id_instrument => 4,
            });
  my $recent_is = $model->recent_instrument_statuses();
  isa_ok($recent_is, 'ARRAY');
  ok (!@{$recent_is}, 'no statuses within last year');
  is( scalar @{$model->instrument_statuses()}, 2, 'two statuses in total');

  lives_ok { $model->status_reset('wash required') } 'new status added';

  $model = npg::model::instrument->new({
             util          => $util,
             id_instrument => 4,
            });
  is( scalar @{$model->recent_instrument_statuses()}, 1, 'one recent status');
  is (scalar @{$model->instrument_statuses()}, 3, 'number of statuses in total');
}

subtest 'recent staging volumes list' => sub {
  plan tests => 23;

  my $util4updates = t::util->new(); # need a new db handle
  lives_ok {$util4updates->load_fixtures;} 'a fresh set of fixtures is loaded';
  my $dbh = $util4updates->dbh;
  $dbh->{AutoCommit} = 1;
  $dbh->{RaiseError} = 1;

  my $status = 'run in progress';
  
  my $model = npg::model::instrument->new({
             util          => $util,
             id_instrument => 3,
            });
  my @volumes = @{$model->recent_staging_volumes()};
  is (@volumes, 1, 'one record is returned');
  is ($volumes[0]->{'volume'}, q[esa-sv-20201215-03],
    qq[volume name for a single run that is associated with the "$status" status]);
  is ($volumes[0]->{'maxdate'}, '2007-06-05', 'the date is correct');

  $model = npg::model::instrument->new({
             util          => $util,
             id_instrument => 14,
            });
  is (scalar @{$model->recent_staging_volumes()}, 0,
    'empty list since no glob is available for a run that is associated with ' .
    qq[the "$status" status]);
  
  $model = npg::model::instrument->new({
             util          => $util,
             id_instrument => 13,
            });
  @volumes = @{$model->recent_staging_volumes()};
  is (@volumes, 1, 'one record is returned');
  is ($volumes[0]->{'volume'}, 'esa-sv-20201215-02', 'volume name is correct');
  is ($volumes[0]->{'maxdate'}, '2007-06-05', 'the date is correct');

  my $new_glob = q[{export,nfs}/esa-sv-20201215-02/IL_seq_data/*/];
  my $update = qq[update run set folder_path_glob='$new_glob' where id_run=15];
  ok($dbh->do($update), 'folder path glob is updated');
  $model = npg::model::instrument->new({
             util          => $util,
             id_instrument => 13,
            });
  @volumes = @{$model->recent_staging_volumes()};
  is ($volumes[0]->{'volume'}, $new_glob, 'a full glob is returned');

  $new_glob = q[/{export,nfs}];
  $update = qq[update run set folder_path_glob='$new_glob' where id_run=15];
  ok($dbh->do($update), 'folder path glob is updated');
  $model = npg::model::instrument->new({
             util          => $util,
             id_instrument => 13,
            });
  @volumes = @{$model->recent_staging_volumes()};
  is ($volumes[0]->{'volume'}, $new_glob, 'a full glob is returned');
  
  $update = q[update run set folder_path_glob='' where id_run=15];
  ok($dbh->do($update), 'folder path glob is updated');
  $model = npg::model::instrument->new({
             util          => $util,
             id_instrument => 13,
            });
  @volumes = @{$model->recent_staging_volumes()};
  is (@volumes, 0, 'an empty list is returned for a zero length glob');

  $update = q[update run_status set id_run_status_dict=2 where ] .
    q[id_run in (3,4,5) and id_run_status_dict=4];
  ok($dbh->do($update), 'run statuses are updated');
  $update = q[update run set folder_path_glob='/{export,nfs}' where id_run=15];
  ok($dbh->do($update), 'folder path glob is updated');
  my $new_date = '2024-05-11 11:23:45';
  $update = qq[update run_status set date='$new_date' where id_run=15 and ] .
    q[id_run_status_dict=2];
  ok($dbh->do($update), 'update the date');
  $update = qq[update run set id_instrument=3 where id_run=15];
  ok($dbh->do($update), 'assign one more run to the instrument');

  $model = npg::model::instrument->new({
             util          => $util,
             id_instrument => 3,
            });
  @volumes = @{$model->recent_staging_volumes()};
  is (@volumes, 2, 'data for two volumes');
  is ($volumes[1]->{'volume'}, q[esa-sv-20201215-03], 'previous volume');
  is ($volumes[1]->{'maxdate'}, '2007-06-05', 'the date is correct');
  is ($volumes[0]->{'volume'}, q[/{export,nfs}], 'latest volume');
  is ($volumes[0]->{'maxdate'}, '2024-05-11', 'the date is correct');

  $dbh->disconnect;
};

1;
