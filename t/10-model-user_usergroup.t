use strict;
use warnings;
use Test::More tests => 9;
use t::util;

use_ok('npg::model::user');
use_ok('npg::model::usergroup');
use_ok('npg::model::user2usergroup');

my $util  = t::util->new({
                fixtures => 1,
                fixtures_path => q[t/data/fixtures],
      });
{
  my $model = npg::model::user->new({
             util     => $util,
             id_user  => 1,
             username => 'test',
            });
  isa_ok($model->users(), 'ARRAY', 'users method');
  ok($model->is_member_of('administrators'), 'is a member of loaders');
}
{
  my $model = npg::model::usergroup->new({
             util     => $util,
             id_usergroup  => 2000,
             groupname => 'loaders',
            });
  my $event_types = $model->event_types();
  isa_ok($event_types, 'ARRAY', 'event_types method');
  my $event_type = $event_types->[0];
  $event_types = $model->event_types();
  is($event_types->[0], $event_type, 'event_types cached ok');
}

{
  my $model = npg::model::user2usergroup->new({
             util     => $util,
             id_usergroup => 2000,
            });
  my $usergroup = $model->usergroup();
  isa_ok($usergroup, 'npg::model::usergroup', 'returns');
  is($model->usergroup(), $usergroup, 'cached usergroup ok');
}

1;
