use strict;
use warnings;
use Test::More tests => 10;
use Test::Exception;

use npg::model::run;
use t::util;

use_ok('npg::model::run_status');

my $util = t::util->new({ fixtures  => 1,});

{
  my $rs = npg::model::run_status->new({
          util => $util,
          id_run_status => 1,
               });
  isa_ok($rs->run(), 'npg::model::run');
  is($rs->run->id_run(), 1, 'id_run');

  isa_ok($rs->user(), 'npg::model::user');
  is($rs->user->id_user(), 1, 'id_user');

  isa_ok($rs->run_status_dict(), 'npg::model::run_status_dict');
  is($rs->run_status_dict->id_run_status_dict(), 1, 'id_user');
}

{
  my $model = npg::model::run_status->new({
             util               => $util,
             id_run             => 1,
             id_run_status_dict => 9,
             id_user            => 1,
            });
  $model->{run} = npg::model::run->new({id_run => 1, util => $util});
  lives_ok { $model->create();}
    'no croak on create for id_run_status_dict = 9 for id_run 1';
}

{
  my $model = npg::model::run_status->new({
             util               => $util,
             id_run             => 1,
             id_run_status_dict => 12,
             id_user            => 1,
            });
  $model->{run} = npg::model::run->new({id_run => 1, util => $util});
  lives_ok { $model->create(); }
    'no croak on create for id_run_status_dict = 12 for id_run 1';
}

{
  my $model = npg::model::run_status->new({
             util               => $util,
             id_run             => 1,
             id_run_status_dict => 4,
             id_user            => 1,
            });
  $model->{run} = npg::model::run->new({id_run => 1, util => $util});
  lives_ok { $model->create() }
    'no croak on create for id_run_status_dict = 4 for id_run 1';
}

1;
