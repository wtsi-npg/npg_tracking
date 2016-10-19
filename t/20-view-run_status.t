use strict;
use warnings;
use Test::More tests => 3;

use t::util;
use npg::model::user;
use npg::model::run_status;

use_ok('npg::view::run_status');

{
  my $mock = {
    q(SELECT ug.id_usergroup, ug.groupname, ug.is_public, ug.description, ug.iscurrent, uug.id_user_usergroup FROM usergroup ug, user2usergroup uug WHERE uug.id_user = ? AND ug.iscurrent = 1 AND ug.id_usergroup = uug.id_usergroup:3) => [{id_usergroup => 104, groupname => 'engineers'}],
    q(SELECT id_usergroup FROM usergroup WHERE groupname = ?:,public) => [[101]],
    q(UPDATE run_status SET iscurrent = 0 WHERE id_run = ?:,NULL) => 1,
    q(INSERT INTO run_status (id_run,date,id_run_status_dict,id_user,iscurrent) VALUES (?,now(),?,?,1):,NULL,NULL,3) => 1,
    q(SELECT LAST_INSERT_ID():) => [[200]],
    q(SELECT id_run_status, id_run, date, id_run_status_dict, id_user, iscurrent FROM run_status WHERE id_run_status=?:200) => [{}],
    q(SELECT rs.id_run_status AS id_run_status, rs.id_run AS id_run, rs.date AS date, rs.id_run_status_dict AS id_run_status_dict, rs.id_user AS id_user, rs.iscurrent AS iscurrent, rsd.description AS description FROM run_status rs, run_status_dict rsd WHERE rs.id_run = ? AND rs.id_run_status_dict = rsd.id_run_status_dict ORDER BY date DESC:NULL) => [{}],
    q(SELECT id_run_lane, id_run, tile_count, tracks, id_project, position FROM run_lane WHERE id_run = ? ORDER BY position:NULL) => [{}],
    q(SELECT ets.description AS service FROM ext_service ets, event_type_service evts WHERE evts.id_event_type = ? AND ets.id_ext_service = evts.id_ext_service:1) => [{}],
    q(SELECT u.id_usergroup, u.groupname, u.is_public, u.description FROM usergroup u, event_type_subscriber ets WHERE ets.id_event_type = ? AND ets.id_usergroup = u.id_usergroup:1) => [{}],
    q(SELECT id_user FROM user2usergroup uug WHERE uug.id_usergroup = ?:NULL) => [{id_user => 3}],
    q(SELECT id_user, username FROM user WHERE id_user=?:3) => [{id_user => 3, username => 'test'}],
    q(SELECT NOW():) => [['2008-01-01']],

  };
  my $util = t::util->new({
    mock => $mock,
  });
  my $user = npg::model::user->new({
    util => $util,
    id_user => 3,
    username => 'engineers',
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
  my $sub = sub {
    my $msg = shift;
    push @{$model->{emails}}, $msg->as_string;
    return;
  };
  MIME::Lite->send('sub',$sub); 
  ok($rs->authorised(), 'engineers ok to create new run_status');
}

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
