use strict;
use warnings;
use Test::More tests => 2;

use t::util;
use npg::model::user;
use npg::model::run_status;

use_ok('npg::view::run_status');

{
  my $mock = {
    q(SELECT ug.id_usergroup, ug.groupname, ug.is_public, ug.description, ug.iscurrent, uug.id_user_usergroup FROM usergroup ug, user2usergroup uug WHERE uug.id_user = ? AND ug.iscurrent = 1 AND ug.id_usergroup = uug.id_usergroup:3) => [{id_usergroup => 104, groupname => 'loaders'}],
    q(SELECT id_usergroup FROM usergroup WHERE groupname = ?:,public) => [[101]],
  };
  my $util = t::util->new({
    mock => $mock,
  });
  my $user = npg::model::user->new({
    util => $util,
    id_user => 3,
    username => 'loaders',
  });
  $util->requestor($user);
  my $model = npg::model::run_status->new({
             'util' => $util,
            });
  my $rs = npg::view::run_status->new({
               'util'   => $util,
               'action' => 'create',
               'model'  => $model,
              });
  ok($rs->authorised(), 'loaders ok to create new run_status');
}

1;
