#########
# Author:        gq1
# Maintainer:    $Author: mg8 $
# Created:       2010-04-27
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-instrument_status_annotation.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-instrument_status_annotation.t $
#
use strict;
use warnings;
use Test::More tests => 9;
use t::util;

use Readonly; Readonly::Scalar our $VERSION => do { my @r = (q$LastChangedRevision: 14928 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

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
