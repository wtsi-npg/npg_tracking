use strict;
use warnings;
use DateTime;
use Test::More tests => 17;
use t::util;

use_ok('npg::model::annotation');

my $util = t::util->new({fixtures => 1});

{
  my $annotation = npg::model::annotation->new();
  isa_ok($annotation, 'npg::model::annotation');
}

{
  my $model = npg::model::annotation->new({
                                           util => $util,
                                          });
  my $annotations = $model->annotations();
  is((scalar @{$annotations}), 23, 'number of annotations');
  is($annotations->[0]->comment(), 'Lack of clusters - run cancelled', 'get comment');
  isa_ok($annotations->[0]->user(), 'npg::model::user', 'user accessor');
}

{
  my $model = npg::model::annotation->new({
                                           util    => $util,
                                           comment => 'A new annotation comment',
                                           id_user => $util->requestor->id_user(),
                                          });
  ok($model->create(), 'creation');
  is($model->id_annotation(), 24, 'new id_annotation');

  my $create_time = $model->date();

  like( $create_time,
        qr/^ (20\d\d) [-] ([01]\d) [-] ([0123]\d) \s+
             ([012]\d) : ([0-5]\d) : ([0-5]\d) $/msx,
        'create timestamp format is sane' );

  my $dt_then = DateTime->new( year      => int substr( $create_time,  0, 4),
                               month     => int substr( $create_time,  5, 2),
                               day       => int substr( $create_time,  8, 2),
                               hour      => int substr( $create_time, 11, 2),
                               minute    => int substr( $create_time, 14, 2),
                               second    => int substr( $create_time, 17, 2),
  );
  my $dt_now  = DateTime->now( time_zone => 'local' );

  my $interval = DateTime::Duration->new( seconds => 10 );

  ok( $dt_then <= $dt_now, 'create time is not in the future' );

  ok( $dt_now - $interval < $dt_then, 'create time is recent' );


  my $model2 = npg::model::annotation->new({
              util => $util,
              id_annotation => $model->id_annotation(),
             });
  is($model2->comment(), $model->comment(), 'comment matches');
}

{
  my $model = npg::model::annotation->new({
                                           util          => $util,
                                           id_annotation => 21,
                                           comment       => 'Revised new annotation comment',
                                          });
  ok($model->update(), 'update');

  my $model2 = npg::model::annotation->new({
                                           util          => $util,
                                           id_annotation => 21,
                                          });
  is($model2->id_annotation(), $model->id_annotation(), 'id_annotation unchanged on update');
  is($model2->id_user(),       $model->id_user(),       'id_user unchanged on update');
  is($model2->comment(), 'Revised new annotation comment', 'comment changed on update');
}

{
  my $model = npg::model::annotation->new({
                                           util          => $util,
                                           id_annotation => 23,
                                          });
  my $list1 = $model->annotations();
  is((scalar @{$list1}), 24, 'list size before deletion');
  $model->delete();

  my $model2 = npg::model::annotation->new({
              util => $util,
             });
  my $list2 = $model2->annotations();
  is((scalar @{$list2}), 23, 'list size after deletion');
}

1;
