use strict;
use warnings;
use Test::More tests => 8;
use t::util;
use npg::model::run;
use npg::view::run;
use Test::Trap;
use CGI;

$ENV{SCRIPT_NAME} = '/cgi-test/npg';

use_ok('npg::view::error');
use_ok('npg::controller');

{
  my $mock = {
        q(SELECT id_user FROM user WHERE username = ?:,public) => [[1]],
        q(SELECT ug.id_usergroup, ug.groupname, ug.is_public, ug.description, uug.id_user_usergroup FROM usergroup ug, user2usergroup uug WHERE uug.id_user = ? AND ug.id_usergroup = uug.id_usergroup:1) => [],
        q(SELECT id_usergroup FROM usergroup WHERE groupname = ?:,public) => [[102]],
        q(SELECT id_usergroup FROM usergroup WHERE groupname = ?:,errors) => [[103]],
          q(SELECT id_user FROM user2usergroup uug WHERE uug.id_usergroup = ?:103) => [{id_user => 1}],
        q(SELECT r.id_run AS id_run, r.batch_id AS batch_id, r.id_instrument AS id_instrument, r.expected_cycle_count AS expected_cycle_count, r.actual_cycle_count AS actual_cycle_count, r.priority AS priority, r.id_run_pair AS id_run_pair, r.is_paired AS is_paired, r.team AS team FROM run r, run_status rs WHERE rs.id_run = r.id_run AND rs.iscurrent = 1 AND rs.id_run_status_dict = ?:) => [],
        q(SELECT id_run_status_dict FROM run_status_dict WHERE description = ?:,run pending) => [],
        q(SELECT rs.id_run_status AS id_run_status, rs.id_run AS id_run, rs.date AS date, rs.id_run_status_dict AS id_run_status_dict, rs.id_user AS id_user, rs.iscurrent AS iscurrent, rsd.description FROM run_status rs, run_status_dict rsd WHERE rs.id_run = ? AND rs.id_run_status_dict = rsd.id_run_status_dict AND rs.iscurrent = 1:) => [],
        q(SELECT id_run_status_dict, description FROM run_status_dict ORDER BY id_run_status_dict:) => [],
        q(SELECT rs.id_run_status AS id_run_status, rs.id_run AS id_run, rs.date AS date, rs.id_run_status_dict AS id_run_status_dict, rs.id_user AS id_user, rs.iscurrent AS iscurrent, rsd.description FROM run_status rs, run_status_dict rsd WHERE rs.id_run = ? AND rs.id_run_status_dict = rsd.id_run_status_dict
                AND rs.iscurrent = 1:0) => [],
        q(SELECT r.id_run AS id_run, r.batch_id AS batch_id, r.id_instrument AS id_instrument, r.expected_cycle_count AS expected_cycle_count, r.actual_cycle_count AS actual_cycle_count, r.priority AS priority, r.id_run_pair AS id_run_pair, r.is_paired AS is_paired, r.team AS team FROM run r, run_status rs WHERE rs.id_run = r.id_run AND rs.iscurrent = 1 AND rs.id_run_status_dict = ?:NULL) => [],
       };

  my $util = t::util->new({mock => $mock});
  trap {
    is(npg::controller->handler($util), 1, 'handler true exit status');
  };
}

{
  my $mock = {
        q(SELECT id_user FROM user WHERE username = ?:,public) => [[1]],
        q(SELECT ug.id_usergroup, ug.groupname, ug.is_public, ug.description, uug.id_user_usergroup FROM usergroup ug, user2usergroup uug WHERE uug.id_user = ? AND ug.id_usergroup = uug.id_usergroup:1) => [],
        q(SELECT id_usergroup FROM usergroup WHERE groupname = ?:,public) => [[102]],
        q(SELECT id_usergroup FROM usergroup WHERE groupname = ?:,errors) => [[103]],
          q(SELECT id_user FROM user2usergroup uug WHERE uug.id_usergroup = ?:103) => [{id_user => 1}],
        q(SELECT r.id_run AS id_run, r.batch_id AS batch_id, r.id_instrument AS id_instrument, r.expected_cycle_count AS expected_cycle_count, r.actual_cycle_count AS actual_cycle_count, r.priority AS priority, r.id_run_pair AS id_run_pair, r.is_paired AS is_paired, r.team AS team FROM run r, run_status rs WHERE rs.id_run = r.id_run AND rs.iscurrent = 1 AND rs.id_run_status_dict = ?:) => [],
        q(SELECT id_run_status_dict FROM run_status_dict WHERE description = ?:,run pending) => [],
        q(SELECT rs.id_run_status AS id_run_status, rs.id_run AS id_run, rs.date AS date, rs.id_run_status_dict AS id_run_status_dict, rs.id_user AS id_user, rs.iscurrent AS iscurrent, rsd.description FROM run_status rs, run_status_dict rsd WHERE rs.id_run = ? AND rs.id_run_status_dict = rsd.id_run_status_dict AND rs.iscurrent = 1:) => ['die'],
        q(SELECT rs.id_run_status AS id_run_status, rs.id_run AS id_run, rs.date AS date, rs.id_run_status_dict AS id_run_status_dict, rs.id_user AS id_user, rs.iscurrent AS iscurrent, rsd.description FROM run_status rs, run_status_dict rsd WHERE rs.id_run = ? AND rs.id_run_status_dict = rsd.id_run_status_dict
                AND rs.iscurrent = 1:0) => [],
        q(SELECT r.id_run AS id_run, r.batch_id AS batch_id, r.id_instrument AS id_instrument, r.expected_cycle_count AS expected_cycle_count, r.actual_cycle_count AS actual_cycle_count, r.priority AS priority, r.id_run_pair AS id_run_pair, r.is_paired AS is_paired, r.team AS team FROM run r, run_status rs WHERE rs.id_run = r.id_run AND rs.iscurrent = 1 AND rs.id_run_status_dict = ?:NULL) => [],
       };

  my $util = t::util->new({mock => $mock});

  trap {
    is(npg::controller->handler($util), 1, 'handler non-zero-exit status');
  };
}

my $util = t::util->new({fixtures => 1});

{
  trap {
    ok(npg::controller->handler($util), 'Five' );
  };
  is($util->username(), q[], 'Six');
}

{
  my $cgi = CGI->new();
  $cgi->param('pipeline', 1);
  $util->cgi($cgi);
  trap {
    ok(npg::controller->handler($util), 'Seven');
  };
  is($util->username(), q[pipeline], 'Eight');
}
