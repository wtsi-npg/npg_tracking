use strict;
use warnings;
use Test::More tests => 51;
use Test::Exception;
use t::util;

use_ok('npg::model::run');
use_ok('npg::model::run_status');
use_ok('npg::model::instrument_status');

my $util = t::util->new({fixtures  => 1});

{
  my $run = npg::model::run->new({id_run => 16, util => $util});
  my $id_instrument = $run->id_instrument();
  $util->dbh->do(
    "update instrument_status set id_instrument_status_dict=7 where id_instrument=$id_instrument and iscurrent=1");
  my $instrument = $run->instrument();
  my $istatus       = $instrument->current_instrument_status()->instrument_status_dict()->description();
  is($istatus, 'planned repair', '"planned repair" is current instrument status in database');

  my $model = npg::model::run_status->new({
             util               => $util,
             id_run             => 16,
             id_run_status_dict => 4,
             id_user            => 1,
            });
  $model->{run} = $run;
  lives_ok { $model->create()} 'run status "run complete" created for id_run 16';

  $istatus = npg::model::instrument->new({util => $util, id_instrument => $id_instrument})->current_instrument_status->instrument_status_dict->description;
  is($istatus, 'planned repair', 'no automatic change from "planned repair" on run complete)');

  $model = npg::model::run_status->new({
             util               => $util,
             id_run             => 16,
             id_run_status_dict => 11,
             id_user            => 1,
            });
  $run = npg::model::run->new({id_run => 16, util => $util,});
  $model->{run} = $run;
  lives_ok { $model->create()} 'run status "run mirrored" created for id_run 16';

  $istatus = npg::model::instrument->new({util => $util, id_instrument => $id_instrument})->current_instrument_status->instrument_status_dict->description;
  is($istatus, 'down for repair',
    'automatic change from "planned service" to "down for repair" on moving a run to "run mirrored"');
}

{
  my $run = npg::model::run->new({id_run => 16,util   => $util,});
  my $model = npg::model::run_status->new({
             util               => $util,
             id_run             => 16,
             id_run_status_dict => 1,
             id_user            => 1,
            });
  $model->{run} = $run;
  lives_ok { $model->create() } 'run status run pending created';  

  my $id_instrument = $run->id_instrument;

  throws_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 7,
  })->create() }
  qr/Instrument IL11 \"planned repair\" status cannot follow current \"down for repair\" status/,
  '"planned repair" cannot follow "down for repair"';

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 3,
  })->create() } '"wash required" can follow "down for repair"';

  my $instr_status = npg::model::instrument->new({util => $util, id_instrument => $id_instrument,})->current_instrument_status->instrument_status_dict->description;
  is($instr_status, 'wash required', '"wash required" is current instrument status');

  throws_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 6,
  })->create() }
  qr/Status \"planned maintenance\" is deprecated/,
  'error creating a deprecated status';

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 7,
  })->create() } '"planned repair" can follow "wash required"';

  is( npg::model::instrument->new({util => $util, id_instrument => $id_instrument,})
       ->current_instrument_status->instrument_status_dict->description,
       'planned repair',
       '"planned repair" is current instrument status');

  $run = npg::model::run->new({id_run => 16,util   => $util,});
  is ($run->id_instrument, $id_instrument, 'new run is on the instrument under test');
  $model = npg::model::run_status->new({
             util               => $util,
             id_run             => 16,
             id_run_status_dict => 5,
             id_user            => 1,
            });
  $model->{run} = $run;
  lives_ok { $model->create() } 'run status run cancelled created';
  is ($run->current_run_status()->run_status_dict()->description(), 'run cancelled', 'run status is run cancelled');

  is (npg::model::instrument->new({util => $util, id_instrument => $id_instrument,})
        ->current_instrument_status->instrument_status_dict->description,
  'down for repair',
  'automatic instrument status change to "down for repair" from "planned repair" on run cancelled');
}

{
  my $run = npg::model::run->new({id_run => 16,util   => $util,});
  my $model = npg::model::run_status->new({
             util               => $util,
             id_run             => 16,
             id_run_status_dict => 5,
             id_user            => 1,
            });
  $model->{run} = $run;
  lives_ok { $model->create() } 'run status run cancelled created';
  is ($run->current_run_status()->run_status_dict()->description(), 'run cancelled', 'run status is run cancelled');

  my $id_instrument = $run->id_instrument;
  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 3,
  })->create() } 'instrument status for "wash required" created';
  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 7,
  })->create() } 'instrument status for "planned repair" created';

  is( npg::model::instrument->new({util => $util, id_instrument => $id_instrument,})
        ->current_instrument_status->instrument_status_dict->description,
  'down for repair',
  'automatic instrument status change to "down for repair" from "planned repair" for a cancelled run');
}

note 'Status change for runs on HiSeq instruments';
{
  my $id_instrument = 36;
  my $id_run = 9951;
  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 7,
  })->create() } 'instrument status for planned repair created';
  my $i = npg::model::instrument->new({util => $util, id_instrument => $id_instrument,});
  is( $i->current_instrument_status->instrument_status_dict->description,
      'planned repair', 'planned repair is current instrument status');

  my $run = npg::model::run->new({id_run => $id_run,util   => $util,});
  lives_ok { $run->save_tags(['fc_slotA']) } 'fc_slotA tag added';
  my $model = npg::model::run_status->new({
             util               => $util,
             id_run             => $id_run,
             id_run_status_dict => 5,
             id_user            => 1,
            });
  $model->{run} = $run;
  lives_ok { $model->create() } 'run status run cancelled created';

  is($i->current_instrument_status->instrument_status_dict->description,
  'down for repair', 'instrument switched to down as the other slot is free'); 
}

{
  my $id_instrument = 35;
  my $id_run1 = 9949;
  my $id_run2 = 9950;

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 11,
  })->create() } 'instrument status for wash in progress created';

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 4,
  })->create() } 'instrument status for wash performed created';

  my $in = npg::model::instrument->new({util => $util, id_instrument => $id_instrument,});
  is($in->current_instrument_status->instrument_status_dict->description,
    'up', 'up is current instrument status - autoupdate');

  my $run = npg::model::run->new({id_run => $id_run1,util   => $util,});
  lives_ok { $run->save_tags(['fc_slotA']) } 'fc_slotA tag added';
  my $model = npg::model::run_status->new({
             util               => $util,
             id_run             => $id_run1,
             id_run_status_dict => 5,
             id_user            => 1,
            });
  $model->{run} = $run;
  lives_ok { $model->create() } 'run status "run cancelled" created for a run in one of the slots';

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 9,
  })->create() } 'instrument status for planned service created';

  is($in->current_instrument_status->instrument_status_dict->description,
    'planned service',
    '"planned service" is current instrument status since one of the slots is not idle ');

  $run = npg::model::run->new({id_run => $id_run2,util   => $util,});
  lives_ok { $run->save_tags(['fc_slotB']) } 'fc_slotB tag added';
  $model = npg::model::run_status->new({
             util               => $util,
             id_run             => $id_run2,
             id_run_status_dict => 5,
             id_user            => 1,
              });
  $model->{run} = $run;
  lives_ok { $model->create() } 'run status "run cancelled" created for a run in the other slot';
  
  is($in->current_instrument_status->instrument_status_dict->description,
   'down for service', '"down for service" is current instrument status since both slots are idle');
}

{
  my $id_instrument = 35;
  my $id_run1 = 9949;
  my $id_run2 = 9950;

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 3,
  })->create() } 'instrument status "wash required" created';
  my $instr_status = npg::model::instrument->new({util => $util, id_instrument => $id_instrument,})->current_instrument_status->instrument_status_dict->description;
  is($instr_status, 'wash required', '"wash required" is current instrument status');

  my $run = npg::model::run->new({id_run => $id_run1,util   => $util,});
  lives_ok { $run->save_tags(['fc_slotA']) } 'fc_slotA tag added';
  my $model = npg::model::run_status->new({
             util               => $util,
             id_run             => $id_run1,
             id_run_status_dict => 1,
             id_user            => 1,
              });
  $model->{run} = $run;
  lives_ok { $model->create() } 'run status "run pending" created for a run in one of the slots';

  $run = npg::model::run->new({id_run => $id_run2,util   => $util,});
  lives_ok { $run->save_tags(['fc_slotB']) } 'fc_slotB tag added';
  $model = npg::model::run_status->new({
             util               => $util,
             id_run             => $id_run2,
             id_run_status_dict => 1,
             id_user            => 1,
              });
  $model->{run} = $run;
  lives_ok { $model->create() } 'run status "run cancelled" created for a run in the other slot';

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 7,
  })->create() } 'instrument status "planned repair" created';

  my $in = npg::model::instrument->new({util => $util, id_instrument => $id_instrument,});
  is($in->current_instrument_status->instrument_status_dict->description,
    'planned repair',
    '"planned repair" is current instrument status since one of the slots is not idle ');

  $run = npg::model::run->new({id_run => $id_run1,util   => $util,});
  $model = npg::model::run_status->new({
             util               => $util,
             id_run             => $id_run1,
             id_run_status_dict => 11,
             id_user            => 1,
              });
  $model->{run} = $run;
  lives_ok { $model->create() } 'run status "run mirrored" created for a run in one of the slots';
  is($in->current_instrument_status->instrument_status_dict->description,
    'planned repair',
    '"planned repair" is current instrument status still');

  $run = npg::model::run->new({id_run => $id_run2,util   => $util,});
  $model = npg::model::run_status->new({
             util               => $util,
             id_run             => $id_run2,
             id_run_status_dict => 11,
             id_user            => 1,
              });
  $model->{run} = $run;
  lives_ok { $model->create() } 'run status "run mirrored" created for a run in the other slots';
  is($in->current_instrument_status->instrument_status_dict->description,
     'down for repair',
     'instrument status changed to "down for repair"');
}

1;
