#########
# Author:        ajb
# Created:       2008-05-08
#
use strict;
use warnings;
use t::util;
use npg::model::run_lane;
use npg::model::user;
use npg::model::annotation;
use English qw{-no_match_vars};

use Test::More tests => 8;
use_ok('npg::model::run_lane_annotation');

#########
# using fixtures to import data
#

my $util  = t::util->new({
        fixtures => 1,
       });
{
  my $model = npg::model::run_lane_annotation->new({
                util => $util,
                id_run_lane_annotation => 1,
               });

  isa_ok($model, 'npg::model::run_lane_annotation', '$model');
  my @fields = $model->fields();
  is($fields[0], 'id_run_lane_annotation', 'first field is id_run_lane_annotation - the primarykey');
  my $run_lane = $model->run_lane();
  isa_ok($run_lane, 'npg::model::run_lane', '$run_lane');
  is($run_lane->id_run_lane(), $model->id_run_lane(), 'fetched correct run_lane');
  my $annotation = $model->annotation();
  isa_ok($annotation, 'npg::model::annotation', '$annotation');
  is($annotation->id_annotation(), $model->id_annotation(), 'fetched correct annotation');
}

{
  my $annotext = 'This is a library annotation for a run lane';

  my $model = npg::model::run_lane_annotation->new({
                util        => $util,
                id_run_lane => 9,
               });
  $util->requestor('joe_annotator');
  $model->annotation->comment($annotext);
  $model->annotation->id_user($util->requestor->id_user());

  eval { $model->create(); };
  is($EVAL_ERROR, q{}, 'no croak on create');
}

1;
