use strict;
use warnings;
use Test::More tests => 6;
use t::util;

my $util  = t::util->new({fixtures => 1});

use_ok('npg::model::tag');
use_ok('npg::model::tag_run_lane');

{
  my $model = npg::model::tag_run_lane->new({
               util            => $util,
               id_tag_run_lane => 1,
              });
  is($model->id_user(), 5, 'load without init');
}

{
  my $model = npg::model::tag_run_lane->new({
               util            => $util,
               id_tag          => 9,
              });
  is($model->id_user(), undef, 'impossible load');
}

{
  my $model = npg::model::tag_run_lane->new({
               util            => $util,
               id_run_lane     => 5,
               id_tag          => 9,
              });
  is($model->id_user(), 5, 'load with init');
}

{
  my $model = npg::model::tag_run_lane->new({
               util            => $util,
               id_tag_run_lane => 1,
               id_run_lane     => 5,
               id_tag          => 9,
              });
  is($model->id_user(), 5, 'populated load without init');
}

1;
