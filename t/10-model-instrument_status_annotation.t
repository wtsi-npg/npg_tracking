use strict;
use warnings;
use Test::More tests => 9;
use t::util;

use_ok('npg::model::instrument_status_annotation');

my $util = t::util->new({fixtures => 1});

{
  my $model = npg::model::instrument_status_annotation->new({
    util => $util,
    id_instrument_status => 1,
  });

  isa_ok($model, 'npg::model::instrument_status_annotation');

  is($model->id_instrument_status, 1, 'correct status id');
  isa_ok($model->instrument_status(), 'npg::model::instrument_status');
  is($model->instrument_status->comment, 'initial setup', 'correct coment for the status');

  isa_ok($model->annotation, 'npg::model::annotation');
  is($model->annotation->id_annotation(), undef, 'no id_annotation create yet');

  $model->annotation->id_user(1);
  $model->annotation->comment('test');    
  $model->create();
  
  is($model->id_annotation(), 24, 'annotation created with id 24');
  
  is($model->id_instrument_status_annotation, 3, 'instrument_status_annotation created with id 3');
}
1;
