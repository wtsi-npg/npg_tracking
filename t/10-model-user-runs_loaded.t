use strict;
use warnings;
use Test::More tests => 7;
use t::util;

use_ok('npg::model::user');
use_ok('npg::model::usergroup');
use_ok('npg::model::user2usergroup');

my $mock  = {
      q(SELECT i.name AS instrument, r.id_run AS id_run, DATE(rs.date) AS date
        FROM instrument i, run_status rs, run_status_dict rsd, run r
        WHERE rs.id_user = ?
        AND rs.id_run_status_dict = rsd.id_run_status_dict
        AND rsd.description = 'run pending'
        AND rs.id_run = r.id_run
        AND r.id_instrument = i.id_instrument
        ORDER BY rs.date DESC:1000) => [{intrument => 'IL1002', id_run => 1000, date => '2008-01-03'},
                                   {intrument => 'IL1001', id_run => 1001, date => '2008-01-02'},
                                   {intrument => 'IL1000', id_run => 1002, date => '2008-01-01'}],
      };
{
  my $util  = t::util->new({mock => $mock});
  my $model = npg::model::user->new({
             util     => $util,
             id_user  => 1000,
             username => 'test',
            });
  $model->{runs_loaded} = 'test';
  is($model->runs_loaded(), 'test', 'nothing fetched as runs_loaded already present');
  $model->{runs_loaded} = undef;
  isa_ok($model->runs_loaded(), 'ARRAY');
  is(scalar@{$model->runs_loaded()}, 3, 'correct number of elements in array');
  isa_ok($model->runs_loaded()->[0], 'HASH');
}

