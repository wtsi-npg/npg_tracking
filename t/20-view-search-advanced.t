use strict;
use warnings;
use Test::More tests => 5;
use t::util;
use npg::model::search;
use CGI;

use_ok('npg::view::search');

my $mock  = {
         q(SELECT id_user FROM user WHERE username = ?:,public) => [[1]],
         q(SELECT id_usergroup FROM usergroup WHERE groupname = ?:,public) => [[1000]],
         q(SELECT ug.id_usergroup, ug.groupname,
                  ug.is_public, ug.description, ug.iscurrent,
                  uug.id_user_usergroup
               FROM   usergroup      ug,
                      user2usergroup uug
               WHERE  uug.id_user = ?
               AND    ug.iscurrent = 1
               AND    ug.id_usergroup = uug.id_usergroup:1) => [{
                                 id_usergroup      => 1000,
                                 groupname         => 'public',
                                 is_public         => 0,
                                 description       => 'public group',
                                 id_user_usergroup => 1,
                                }],
         q(SELECT 'run' AS type, id_run AS primary_key,
                  'run id' AS location, '' AS context
               FROM run WHERE id_run=?:,123) => [['run',123,'run id','']],
         q(SELECT 'run' AS type, id_run AS primary_key,
                  'batch id' AS location, '' AS context
               FROM run WHERE batch_id=?:,123) => [['run',3000,'batch id','']],
         q(SELECT 'run' AS type, ra.id_run AS primary_key,
                  'annotation' AS location, a.comment AS context
               FROM annotation a, run_annotation ra
               WHERE ra.id_annotation = a.id_annotation AND a.comment LIKE ?
               ORDER BY date DESC LIMIT 100:,%123%) => [['run',3000,'annotation','A comment 123']],
         q(SELECT 'run' AS type, id_run AS primary_key,
                  'ST library name' AS location, content AS context
               FROM st_cache WHERE type = 'library'
               AND  content LIKE ?:,%123%) => [['run',3000,'ST library name','A 123 sample']],
         q(SELECT 'run' AS type, id_run AS primary_key,
                  'ST project name' AS location, content AS context
               FROM st_cache WHERE type = 'project'
               AND content LIKE ?:,%123%)  => [['run',3000,'ST project name','A 123 project']],
         q(SELECT DISTINCT run.id_run FROM run:) => [{id_run => 1000}, {id_run => 1001}],
         q(SELECT 'run' AS type, tr.id_run AS primary_key, 'tag' AS location, tag AS context FROM tag t, tag_run tr WHERE tr.id_tag = t.id_tag AND t.tag LIKE ? ORDER BY tr.date DESC LIMIT 100:,%123%) => [{}],
         q(SELECT 'run_lane' AS type, trl.id_run_lane AS primary_key, 'tag' AS location, tag AS context FROM tag t, tag_run_lane trl WHERE trl.id_tag = t.id_tag AND t.tag LIKE ? ORDER BY trl.date DESC LIMIT 100:,%123%) => [{}],
         q(SELECT tr.id_run, t.tag FROM tag t, tag_run tr WHERE t.id_tag = tr.id_tag AND tr.id_run in (1000,1001) ORDER BY tr.id_run:) => [{id_run => 1000, tag => 'good'}, {id_run => 1001, tag => 'bad'}],
         q(SELECT id_run, batch_id, id_instrument, expected_cycle_count, actual_cycle_count, priority, id_run_pair, is_paired, team, id_instrument_format FROM run WHERE id_run=?:123) => [{id_run => 123, batch_id => 200, id_instrument => 3, expected_cycle_count => 37, actual_cycle_count => 1, priority => 1, id_run_pair => undef, is_paired => 1, team => 'joint'}],
         q(SELECT id_run, batch_id, id_instrument, expected_cycle_count, actual_cycle_count, priority, id_run_pair, is_paired, team, id_instrument_format FROM run WHERE id_run=?:3000) => [{id_run => 3000, batch_id => 300, id_instrument => 3, expected_cycle_count => 37, actual_cycle_count => 1, priority => 1, id_run_pair => undef, is_paired => 0, team => 'joint'}],
        };

{
  my $cgi   = CGI->new();
  my $util  = t::util->new({
                mock => $mock,
                cgi  => $cgi,
               });

  my $model = npg::model::search->new({
                       util  => $util,
                      });
  my $view  = npg::view::search->new({
                      util   => $util,
                      model  => $model,
                      action => 'read',
                      aspect => 'list_advanced',
                     });

  isa_ok($view, 'npg::view::search');
  my $render;
  eval { $render = $view->render(); };
  ok($util->test_rendered($render, 't/data/rendered/20-view-search-advanced.html'), '20-view-search-list_advanced rendered ok');
}
{
  my $cgi   = CGI->new();
  $cgi->param('query', 1);
  my $util  = t::util->new({
                mock => $mock,
                cgi  => $cgi,
               });

  my $model = npg::model::search->new({
                       util  => $util,
                      });
  my $view  = npg::view::search->new({
                      util   => $util,
                      model  => $model,
                      action => 'read',
                      aspect => 'list_advanced',
                     });
  isa_ok($view, 'npg::view::search');
  ok($util->test_rendered($view->render(), 't/data/rendered/20-view-search-advanced-results.html'), '20-view-search-list_advanced results rendered ok');
}

1;
