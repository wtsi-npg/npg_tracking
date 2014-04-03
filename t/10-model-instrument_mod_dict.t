use strict;
use warnings;
use t::util;
use Test::More tests => 12;

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
