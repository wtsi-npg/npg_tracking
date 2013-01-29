#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-03-28
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-instrument_mod.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-instrument_mod.t $
#
use strict;
use warnings;
use t::util;
use Test::More tests => 15;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };
use_ok('npg::model::instrument_mod');

{
  my $util  = t::util->new({fixtures => 1});
  my $model = npg::model::instrument_mod->new({
    util => $util,
    id_user => 1,
    id_instrument => 3,
    id_instrument_mod_dict => 1,
    date_added => '2008-01-01',
    iscurrent => 1,
  });
  isa_ok($model, 'npg::model::instrument_mod', '$model');
  my $user = $model->user();
  isa_ok($user, 'npg::model::user', '$user');
  my $instrument = $model->instrument();
  isa_ok($instrument, 'npg::model::instrument', '$instrument');
  my $instruments = $model->instruments();
  isa_ok($instruments, 'ARRAY', '$instruments');
  isa_ok($instruments->[0], 'npg::model::instrument', '$instruments->[0]');
  my $imd = $model->instrument_mod_dict();
  isa_ok($imd, 'npg::model::instrument_mod_dict', '$imd');
  my $imds = $model->instrument_mod_dicts();
  isa_ok($imds, 'ARRAY', '$imds');
  isa_ok($imds->[0], 'npg::model::instrument_mod_dict', '$imds->[0]');
  ok($model->save(), 'save (create) returns ok');
  is($model->id_instrument_mod(), 20, 'new id_instrument_mod ok');
  $model->date_removed('2008-02-01');
  $model->iscurrent(0);
  ok($model->save(), 'save (update) returns ok');
  is($model->id_instrument_mod(), 20, 'id_instrument_mod still the same');
  is($model->instrument_mod_dict->description, 'PE module', 'correct mode dict description');
  is($model->instrument_mod_dict->revision, 'A', 'correct mode dict revision');
}
