#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-03-28
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-instrument_mod_dict.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-instrument_mod_dict.t $
#
use strict;
use warnings;
use t::util;
use Test::More tests => 12;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };
use_ok('npg::model::instrument_mod_dict');
{
  my $util  = t::util->new({fixtures => 1});
  my $model = npg::model::instrument_mod_dict->new({
    util => $util,
    description => 'test',
    revision => 'a',
  });
  isa_ok($model, 'npg::model::instrument_mod_dict', '$model');
  my $imds = $model->instrument_mod_dicts();
  my $array_length = scalar@{$imds};
  isa_ok($imds, 'ARRAY', '$model->instrument_mod_dicts()');
  isa_ok($imds->[0], 'npg::model::instrument_mod_dict', '$imds->[0]');
  is($imds->[0]->description(), 'Mode Scrambler', 'first row object description is Mode Scrambler');
  is($imds->[0]->revision(), 'MKIV', 'first row object revision is MKIV');
  my $descriptions = $model->descriptions();
  isa_ok($descriptions, 'ARRAY', '$model->descriptions()');
  is($descriptions->[0]->[0], 'Mode Scrambler', 'first description is Mode Scrambler');
  ok($model->save(), 'save (create) returns ok');
  is($model->id_instrument_mod_dict(), 12, 'new id_instrument_mod_dict ok');
  $model->revision('b');
  ok($model->save(), 'save (update) returns ok');
  is($model->id_instrument_mod_dict(), 12, 'id_instrument_mod_dict still the same');
}
