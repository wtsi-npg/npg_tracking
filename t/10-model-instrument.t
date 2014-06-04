use strict;
use warnings;
use t::util;
use Test::More tests => 121;
use Test::Deep;
use Test::Exception;

use_ok('npg::model::instrument');

my $util = t::util->new({ fixtures => 1 });

{
  my $inst = npg::model::instrument->new({
            id_instrument => 3,
            util          => $util,
           });
  my $runs = $inst->runs();
  is((scalar @{$runs}), 12, 'all runs for instrument');
}

{
  my $inst = npg::model::instrument->new({
            id_instrument => 3,
            util          => $util,
           });
  my $runs = $inst->runs({len => 4});
  is((scalar @{$runs}), 4, 'limited all runs for instrument');
  is($runs->[0]->id_run(), 12, 'first run ok');
}

{
  my $inst = npg::model::instrument->new({
            id_instrument => 3,
            util          => $util,
           });
  my $runs = $inst->runs({
        len   => 4,
        start => 1,
       });
  is((scalar @{$runs}), 4, 'limited, offset all runs for instrument');
  is($runs->[0]->id_run(), 11, 'first run ok');
}

{
  my $inst = npg::model::instrument->new({
            id_instrument => 3,
            util          => $util,
           });
  my $runs = $inst->runs({
        id_run_status_dict => 11,
       });
  is((scalar @{$runs}), 3, 'id_rsd-restricted runs for instrument');
}

{
  my $inst = npg::model::instrument->new({
            id_instrument => 3,
            util          => $util,
           });
  my $runs = $inst->runs({
        id_run_status_dict => 11,
        len => 2,
       });
  is((scalar @{$runs}), 2, 'limited, id_rsd-restricted runs for instrument');
  is($runs->[0]->id_run(), 5, 'first run ok');
  is($runs->[1]->id_run(), 12, 'second run ok');
}

{
  my $inst = npg::model::instrument->new({
            id_instrument => 3,
            util          => $util,
           });
  my $runs = $inst->runs({
        id_run_status_dict => 11,
        len   => 2,
        start => 1,
       });
  is((scalar @{$runs}), 2, 'limited, offset, id_rsd-restricted runs for instrument');
  is($runs->[0]->id_run(), 12, 'first run ok');
  is($runs->[1]->id_run(), 11, 'second run ok');
}

{
  my $inst = npg::model::instrument->new({
            id_instrument => 3,
            util          => $util,
           });
  is($inst->count_runs(), 12);
  is($inst->count_runs({id_run_status_dict=>11}), 3);
}

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

  isa_ok($model->utilisation(), 'ARRAY', '$model->utilisation()');
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
  my $runs = $model->runs();
  isa_ok($runs, 'ARRAY', '$model->runs()');
  isa_ok($runs->[0], 'npg::model::run', '$model->runs()->[0]');

  my $current_run = $model->current_run();
  isa_ok($current_run, 'npg::model::run', '$model->current_run()');
  is($model->current_run(), $current_run, '$model->current_run() cached ok');
  is($model->model(), 'HK', '$model->model() retrieved correctly');
  is($model->id_manufacturer(), 10, '$model->id_manufacturer() retrieved correctly');
  isa_ok($model->manufacturer(), 'npg::model::manufacturer', '$model->id_manufacturer()');

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

  $util->catch_email($model);
  is( scalar @{ $model->{emails} }, 0, q{no email sent} );

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
  #throws_ok {$model->status_reset('wash performed')} qr/cBot1 \"wash performed\" status cannot follow current \"wash required\" status/, 'error moving from "wash required" directly to "wash performed"';
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
  my $model = npg::model::instrument->new({util => $util, id_instrument => 48,});
  ok(!$model->does_sequencing, 'instrument does not do sequencing');
  ok(!$model->is_two_slot_instrument, 'is not two slot instrument');
  ok($model->is_cbot_instrument, 'is cbot instrument');
  ok (!$model->is_idle, 'instrument is not idle');
  ok (!$model->status_to_change_to, 'no status to change to');
  ok (!$model->autochange_status_if_needed, 'no autochange status for cbot');
  is($model->fc_slots2current_runs, undef, 'does not have mapping of slots to current runs');
  is($model->fc_slots2blocking_runs, undef, 'does not have mapping of slots to blocking runs')
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

1;
