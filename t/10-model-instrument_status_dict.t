use strict;
use warnings;
use t::util;
use Test::More tests => 20;
use Test::Trap;

our $ISD     = 'npg::model::instrument_status_dict';

use_ok($ISD);

my $util = t::util->new({fixtures => 1});

{
  my $model = $ISD->new({
       util        => $util,
       description => 'up',
      });
  isa_ok($model, $ISD, '$model');
  is($model->id_instrument_status_dict(), 1, 'initialised by description ok');
}

{
  trap {
    my $model = $ISD->new({
         util        => 'bla',
         description => 'fail!',
        });
    is($model->init(), undef, 'database query failure');
  };
}

{
  my $model = $ISD->new({
       util                      => $util,
       id_instrument_status_dict => 2,
      });
  isa_ok($model, $ISD, '$model');
  is($model->description(), 'down', 'initialised by id_instrument_status_dict ok');
  is($model->iscurrent, 0, 'depricated flag is retrieved');
}

{
  my $model = $ISD->new({
       util => $util,
      });
  my $isds = $model->instrument_status_dicts();
  isa_ok($isds, 'ARRAY', 'unprimed cache $model->instrument_status_dicts()');
  is((scalar @{$isds}), 11, 'unprimed cache number of instrument_status_dicts');
  is_deeply($isds, $model->instrument_status_dicts(), 'primed cache insturment_status_dicts');
}

{
  my $model = $ISD->new({
       util => $util,
       id_instrument_status_dict => 2,
      });
  my $instruments = $model->instruments();
  isa_ok($instruments, 'ARRAY', '$model->instruments()');
  is_deeply($model->instruments(), $instruments, 'primed cache instruments');

  isa_ok($instruments->[0], 'npg::model::instrument', '$model->instruments->[0]');
}

{
  my $model = $ISD->new({
       util        => $util,
       description => 'another status',
                         iscurrent   => 1,
      });
  ok($model->create(), 'instrument_status_dict create');

  is($model->id_instrument_status_dict(), 12, 'new status id');

  $model->description('status update');
  ok($model->iscurrent, 'status is current');
  ok($model->update(), 'instrument_status_dict update');
  is($model->id_instrument_status_dict(), 12, 'unchanged status id');
}

{

  my $model = $ISD->new({
       util => $util,
       id_instrument_status_dict => 2,
      });
  is(join(q[;], sort keys %npg::model::instrument_status_dict::SHORT_DESCRIPTIONS),
  'down;down for repair;down for service;planned maintenance;planned repair;planned service;request approval;up;wash in progress;wash performed;wash required',
  'statuses for which short descriptions are available');
  is( $npg::model::instrument_status_dict::SHORT_DESCRIPTIONS{'wash required'},
      'wash',
      'short status description for "wash required"');
}

1;
