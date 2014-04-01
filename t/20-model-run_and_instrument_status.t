use strict;
use warnings;
use Test::More tests => 56;
use Test::Exception;
use t::util;

use_ok('npg::model::run');
use_ok('npg::model::run_status');
use_ok('npg::model::instrument_status');

my $util = t::util->new({
       fixtures  => 1,
      });

{
  my $model = npg::model::run_status->new({
             util               => $util,
             id_run             => 16,
             id_run_status_dict => 4,
             id_user            => 1,
            });
  my $run = npg::model::run->new({id_run => 16,util   => $util,});
  $model->{run} = $run;

  my $instr_status = npg::model::instrument->new({util => $util, id_instrument => $model->{run}->id_instrument})->current_instrument_status->instrument_status_dict->description;

  is($instr_status, 'planned maintenance', 'planned maintenance is current instrument status in database');
  $util->catch_email($model);

  lives_ok { $model->create()} 'run status run complete created for id_run 16';

  $instr_status = npg::model::instrument->new({util => $util, id_instrument => $model->{run}->id_instrument})->current_instrument_status->instrument_status_dict->description;
  is($instr_status, 'planned maintenance', 'no automatic change from planned maintenance on run complete)');

  $model = npg::model::run_status->new({
             util               => $util,
             id_run             => 16,
             id_run_status_dict => 11,
             id_user            => 1,
            });
  $run = npg::model::run->new({id_run => 16,util   => $util,});
  $model->{run} = $run;
  $util->catch_email($model);
  lives_ok { $model->create()} 'run status run mirrored created for id_run 16';

  $instr_status = npg::model::instrument->new({util => $util, id_instrument => $model->{run}->id_instrument})->current_instrument_status->instrument_status_dict->description;
  is($instr_status, 'down for repair',
  'automatic change from planned maintenance to down for repair on moving a run to run mirrored');
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
  $util->catch_email($model);
  lives_ok { $model->create() } 'run status run pending created';  

  my $id_instrument = $run->id_instrument;

  throws_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 7,
  })->create() }
  qr/Instrument IL11 \"planned repair\" status cannot follow current \"down for repair\" status/,
  'planned maintenance cannot follow down';

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 5,
  })->create() } 'request approval can follow down';

  my $instr_status = npg::model::instrument->new({util => $util, id_instrument => $id_instrument,})->current_instrument_status->instrument_status_dict->description;
  is($instr_status, 'request approval', 'request approval is current instrument status');

  throws_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 6,
  })->create() }
  qr/Status \"planned maintenance\" is depricated/,
  'error creating a depricated status';

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 7,
  })->create() } 'planned repair can follow request approval';

  is( npg::model::instrument->new({util => $util, id_instrument => $id_instrument,})
       ->current_instrument_status->instrument_status_dict->description,
       'planned repair',
       'planned repair is current instrument status');

  $run = npg::model::run->new({id_run => 16,util   => $util,});
  is ($run->id_instrument, $id_instrument, 'new run is on the instrument under test');
  $model = npg::model::run_status->new({
             util               => $util,
             id_run             => 16,
             id_run_status_dict => 5,
             id_user            => 1,
            });
  $model->{run} = $run;
  $util->catch_email($model);
  lives_ok { $model->create() } 'run status run cancelled created';
  is ($run->current_run_status()->run_status_dict()->description(), 'run cancelled', 'run status is run cancelled');

  is (npg::model::instrument->new({util => $util, id_instrument => $id_instrument,})
        ->current_instrument_status->instrument_status_dict->description,
  'down for repair',
  'automatic instrument status change to "down for repair" from planned maintenance on run cancelled');
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
  $util->catch_email($model);
  lives_ok { $model->create() } 'run status run cancelled created';
  is ($run->current_run_status()->run_status_dict()->description(), 'run cancelled', 'run status is run cancelled');

  my $id_instrument = $run->id_instrument;

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 5,
  })->create() } 'instrument status for request approval created';

  my $instr_status = npg::model::instrument->new({util => $util, id_instrument => $id_instrument,})->current_instrument_status->instrument_status_dict->description;
  is($instr_status, 'request approval', 'request approval is current instrument status');

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 7,
  })->create() } 'instrument status for planned repair created';

  is( npg::model::instrument->new({util => $util, id_instrument => $id_instrument,})
        ->current_instrument_status->instrument_status_dict->description,
  'down for repair',
  'automatic instrument status change to "down for repair" from "planned rrepair" for a cancelled run');
}

diag 'Status change for runs on HiSeq instruments';
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
  $util->catch_email($model);
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
  $util->catch_email($model);
  lives_ok { $model->create() } 'run status run cancelled created for a run in one of the slots';

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 9,
  })->create() } 'instrument status for planned service created';

  is($in->current_instrument_status->instrument_status_dict->description,
    'planned service',
    'planned service is current instrument status since one of the slots is not idle ');

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 8,
  })->create() } 'instrument status for down for repair created';

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 5,
  })->create() } 'instrument status for request approval created';

  is($in->current_instrument_status->instrument_status_dict->description,
    'request approval', 'request approval is current instrument status');

  $run = npg::model::run->new({id_run => $id_run2,util   => $util,});
  lives_ok { $run->save_tags(['fc_slotB']) } 'fc_slotB tag added';
  $model = npg::model::run_status->new({
             util               => $util,
             id_run             => $id_run2,
             id_run_status_dict => 5,
             id_user            => 1,
              });
  $model->{run} = $run;
  $util->catch_email($model);
  lives_ok { $model->create() } 'run status run cancelled created for a run in the other slot';

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 9,
  })->create() } 'instrument status for planned service created';
  
  is($in->current_instrument_status->instrument_status_dict->description,
   'down for service', 'down for service is current instrument status since both slots are idle');
}

{
  my $id_instrument = 35;
  my $id_run1 = 9949;
  my $id_run2 = 9950;

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 5,
  })->create() } 'instrument status for request approva created';
  my $instr_status = npg::model::instrument->new({util => $util, id_instrument => $id_instrument,})->current_instrument_status->instrument_status_dict->description;
  is($instr_status, 'request approval', 'request approva is current instrument status');

  my $run = npg::model::run->new({id_run => $id_run1,util   => $util,});
  lives_ok { $run->save_tags(['fc_slotA']) } 'fc_slotA tag added';
  my $model = npg::model::run_status->new({
             util               => $util,
             id_run             => $id_run1,
             id_run_status_dict => 1,
             id_user            => 1,
              });
  $model->{run} = $run;
  $util->catch_email($model);
  lives_ok { $model->create() } 'run status run pending created for a run in one of the slots';

  $run = npg::model::run->new({id_run => $id_run2,util   => $util,});
  lives_ok { $run->save_tags(['fc_slotB']) } 'fc_slotB tag added';
  $model = npg::model::run_status->new({
             util               => $util,
             id_run             => $id_run2,
             id_run_status_dict => 1,
             id_user            => 1,
              });
  $model->{run} = $run;
  $util->catch_email($model);
  lives_ok { $model->create() } 'run status run cancelled created for a run in the other slot';

  lives_ok { npg::model::instrument_status->new({
    util => $util,
    id_instrument => $id_instrument,
    id_user => 1,
    id_instrument_status_dict => 7,
  })->create() } 'instrument status for planned repair created';

  my $in = npg::model::instrument->new({util => $util, id_instrument => $id_instrument,});
  is($in->current_instrument_status->instrument_status_dict->description,
    'planned repair',
    'planned repair is current instrument status since one of the slots is not idle ');

  $run = npg::model::run->new({id_run => $id_run1,util   => $util,});
  $model = npg::model::run_status->new({
             util               => $util,
             id_run             => $id_run1,
             id_run_status_dict => 11,
             id_user            => 1,
              });
  $model->{run} = $run;
  $util->catch_email($model);
  lives_ok { $model->create() } 'run status run mirrored created for a run in one of the slots';
  is($in->current_instrument_status->instrument_status_dict->description,
    'planned repair',
    'planned repair is current instrument status still');

  $run = npg::model::run->new({id_run => $id_run2,util   => $util,});
  $model = npg::model::run_status->new({
             util               => $util,
             id_run             => $id_run2,
             id_run_status_dict => 11,
             id_user            => 1,
              });
  $model->{run} = $run;
  $util->catch_email($model);
  lives_ok { $model->create() } 'run status run mirrored created for a run in one of the slots';
  is($in->current_instrument_status->instrument_status_dict->description,
     'down for repair',
     'instrument status changed to down for repair');
}

1;
