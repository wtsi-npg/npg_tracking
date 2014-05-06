use strict;
use warnings;
use Test::More tests => 78;
use Test::Exception;
use Test::Deep;
use MIME::Lite;
use CGI;
use t::util;
use t::request;

use_ok('npg::view::run');

my $util = t::util->new({fixtures  => 1,});

{
  my $view = npg::view::run->new({
          util  => $util,
          model => npg::model::run->new({
                 util   => $util,
                 id_run => q(),
                }),
         });
  isa_ok($view, 'npg::view::run', 'isa npg::view::run');
}

{
  my $view = npg::view::run->new({
          util  => $util,
          action => q{list},
          aspect => q{list_stuck_runs},
          model => npg::model::run->new({
                 util   => $util,
                 id_run => q(),
                }),
         });
  ok($util->test_rendered($view->render(), 't/data/rendered/run/list_stuck_runs.html'), 'list_stuck_runs render is ok');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run;add',
           REQUEST_METHOD => 'GET',
           username       => 'joe_loader',
           util           => $util,
          });
  ok($util->test_rendered($str, 't/data/rendered/run.html;add'), 'add render');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run;add',
           REQUEST_METHOD => 'GET',
           username       => 'joe_r_n_d',
           util           => $util,
          });
  like($str, qr/<option\ value=\"RAD\"\ selected=\"selected\">RAD<\/option>/mix, 'add render r+d');
}

{
  my @emails;
  my $sub = sub {
     my $msg = shift;
           push @emails, $msg->as_string;
     return;
          };
  MIME::Lite->send('sub',$sub);

  my $str = t::request->new({
			     PATH_INFO      => '/run',
			     REQUEST_METHOD => 'POST',
			     username       => 'joe_loader',
			     util           => $util,
			     cgi_params     => {
						id_instrument        => 3,
						id_run_pair          => 0,
						team                 => 'RAD',
						batch_id             => 42,
						tracks               => 3,
						lane_1_tile_count    => 330,
						expected_cycle_count => 37,
						priority             => 1,
					       },

			    });
  ok($util->test_rendered($str, 't/data/rendered/run.html-POST'), 'loader create render ok');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run',
           REQUEST_METHOD => 'POST',
           username       => 'public',
           util           => $util,
          });
  like($str, qr/not\ authorised/mix, 'non-pipeline access to run;create');
}

{
  my @emails;
  my $sub = sub {
     my $msg = shift;
           push @emails, $msg->as_string;
     return;
          };
  MIME::Lite->send('sub',$sub);

  my $str  = t::request->new({
			      PATH_INFO      => '/run/16.xml',
			      REQUEST_METHOD => 'POST',
			      username       => 'pipeline',
			      util           => $util,
			      cgi_params     => {
						 id_instrument        => 3,
						 id_run_pair          => 0,
						 team                 => 'RAD',
						 batch_id             => 42,
						 tracks               => 3,
						 lane_1_tile_count    => 330,
						 expected_cycle_count => 37,
						 priority             => 1,
						},
			     });
  ok($util->test_rendered($str, 't/data/rendered/run/16;update_xml'), 'loader update_xml');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run/42.xml',
           REQUEST_METHOD => 'POST',
           username       => 'public',
           util           => $util,
          });
  like($str, qr/not\ authorised/mix, 'non-pipeline access to run/x;update_xml');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run/16;update_statuses',
           REQUEST_METHOD => 'POST',
           username       => 'public',
           util           => $util,
          });
  like($str, qr{not\ authorised}mx, 'public access to /run/x;update_statuses');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run;add',
           REQUEST_METHOD => 'GET',
           username       => 'public',
           util           => $util,
          });
  like($str, qr{not\ authorised}mx, 'public access to run;add');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run;add',
           REQUEST_METHOD => 'GET',
           username       => 'joe_loader',
           util           => $util,
          });
  unlike($str, qr/not\ authorised/mix, 'loader access to run;add');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run/1.xml',
           REQUEST_METHOD => 'GET',
           username       => 'public',
           util           => $util,
          });
  ok($util->test_rendered($str, 't/data/rendered/run/1.xml'), 'read_xml render ok');
}

{
  # placed last so we have some current runs to list
  my $str = t::request->new({
           PATH_INFO      => '/run',
           REQUEST_METHOD => 'GET',
           username       => 'public',
           util           => $util,
          });
  ok($util->test_rendered($str, 't/data/rendered/run.html'), 'html list render');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run',
           REQUEST_METHOD => 'GET',
           username       => 'public',
           util           => $util,
                             cgi_params     => {id_run_status_dict => 'all', id_instrument => 3, },
          });
  ok($util->test_rendered($str, 't/data/rendered/run/runs_on_instrument.html'), 'html list render run instrument 3 all statuses');
}

{  
  my $str = t::request->new({
           PATH_INFO      => '/run/1234',
           REQUEST_METHOD => 'GET',
           username       => 'joe_loader',
           util           => $util,
          });
  unlike  ($str, qr/id_run_status_dict/, 'run status list is empty for non-analyst user for run at status qc_complete');
  unlike  ($str, qr/add_status/, 'yellow edit pencil is not visible for non-analyst user for run at status qc_complete');

}

{
  my $str = t::request->new({
           PATH_INFO      => '/run/1#run_status_form',
           REQUEST_METHOD => 'GET',
           username       => 'joe_loader',
           util           => $util,
           cgi_params     => {
            batch_id => 42,
                 },
          });
  ok($util->test_rendered($str, 't/data/rendered/run_status/t_run_status_list_sorted_from_analysis_complete.html'), 'run status list shows following statuses for non-analyst user for run at status analysis_complete');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run/2#run_status_form',
           REQUEST_METHOD => 'GET',
           username       => 'joe_analyst',
           util           => $util,
           cgi_params     => {
            batch_id => 42,
                 },
          });
  ok($util->test_rendered($str, 't/data/rendered/run_status/t_run_status_list_sorted.html'), 'run status list is sorted and filtered but displayed in full for analyst user');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run/group;update_statuses',
           REQUEST_METHOD => 'POST',
           username       => 'joe_loader',
           util           => $util,
           cgi_params     => {
            id_runs            => 1,
            id_run_status_dict => 21,
                 },
          });
  is($util->cgi->param('type'), 'group', 'type attribute set');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run/group;update_statuses',
           REQUEST_METHOD => 'POST',
           username       => 'joe_loader',
           util           => $util,
           cgi_params     => {
            id_runs            => 1,
            id_run_status_dict => 21,
                 },
          });
  like($str, qr/updated\ statuses\ ok/mix, 'update_statuses');
}

{
  my $run1 = npg::model::run->new({
           util   => $util,
           id_run => 1,
          });
  for my $lane (@{$run1->run_lanes()}) {
    is($lane->tracks(), 2, 'existing tracks for run_lane');
    is($lane->tile_count(), 200, 'existing tile_count for run_lane');
  }
  my $str = t::request->new({
           PATH_INFO      => '/run/1.xml',
           REQUEST_METHOD => 'POST',
           username       => 'pipeline',
           util           => $util,
           cgi_params     => {
            tile_columns => 3,
            tile_rows    => 110,
                 },
          });
  unlike($str, qr/error/mix, 'update tile_columns & tile_rows');

  my $run2 = npg::model::run->new({
           util   => $util,
           id_run => 1,
          });
  for my $lane (@{$run2->run_lanes()}) {
    is($lane->tracks(), 3, 'updated tracks for run_lane');
    is($lane->tile_count(), 330, 'updated tile_count for run_lane');
  }
}

{
  my $runs1 = [map { $_->id_run() } @{npg::model::run->new({util=>$util})->runs()}];
  my $str   = t::request->new({
			       PATH_INFO      => '/run',
			       REQUEST_METHOD => 'POST',
			       username       => 'joe_loader',
			       util           => $util,
			       cgi_params     => {
						  id_instrument        => 3,
						  id_run_pair          => 0,
						  team                 => 'RAD',
						  batch_id             => 42,
						  tracks               => 3,
						  lane_1_tile_count    => 330,
						  expected_cycle_count => 37,
						  priority             => 1,
						 },
			      });
  my $runs2 = {map { $_->id_run() => 1 } @{npg::model::run->new({util=>$util})->runs()}};

  for my $run (@{$runs1}) {
    delete $runs2->{$run};
  }

  is((scalar keys %{$runs2}), 1, 'one new run');
  my ($new_id) = keys %{$runs2};
  my $run = npg::model::run->new({
          util   => $util,
          id_run => $new_id,
         });
  is($run->is_dev(), 1, 'r&d run');
}

{
  my $runs1 = [map { $_->id_run() } @{npg::model::run->new({util=>$util})->runs()}];
  my $str   = t::request->new({
			       PATH_INFO      => '/run',
			       REQUEST_METHOD => 'POST',
			       username       => 'joe_loader',
			       util           => $util,
			       cgi_params     => {
						  id_instrument        => 3,
						  id_run_pair          => 0,
						  batch_id             => 42,
						  tracks               => 3,
						  lane_1_tile_count    => 330,
						  expected_cycle_count => 37,
						  team                 => 'A',
						  priority             => 1,
						 },
			      });

  unlike($str, qr/Error/smx);
  my $runs2 = {map { $_->id_run() => 1 } @{npg::model::run->new({util=>$util})->runs()}};

  for my $run (@{$runs1}) {
    delete $runs2->{$run};
  }

  is((scalar keys %{$runs2}), 1, 'one new run');
  my ($new_id) = keys %{$runs2};
  my $run = npg::model::run->new({
          util   => $util,
          id_run => $new_id,
         });
  is($run->is_dev(), 0, 'run is not dev');
}

{
  my $runs1 = [map { $_->id_run() } @{npg::model::run->new({util=>$util})->runs()}];
  my $str   = t::request->new({
			       PATH_INFO      => '/run',
			       REQUEST_METHOD => 'POST',
			       username       => 'joe_r_n_d',
			       util           => $util,
			       cgi_params     => {
						  id_instrument        => 3,
						  id_run_pair          => 0,
						  team                 => 'RAD',
						  batch_id             => 42,
						  tracks               => 3,
						  lane_1_tile_count    => 330,
						  expected_cycle_count => 37,
						  priority             => 1,
						 },
			      });
  my $runs2 = {map { $_->id_run() => 1 } @{npg::model::run->new({util=>$util})->runs()}};

  for my $run (@{$runs1}) {
    delete $runs2->{$run};
  }

  is((scalar keys %{$runs2}), 1, 'one new run');
  my ($new_id) = keys %{$runs2};
  my $run = npg::model::run->new({
          util   => $util,
          id_run => $new_id,
         });
  is($run->is_dev(), 1, 'r+d user can set is_dev');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run.xml',
           REQUEST_METHOD => 'GET',
           username       => 'public',
           util           => $util,
           cgi_params     => {
            id_run => q[11,12,14,95],
                 },
          });

  ok($util->test_rendered($str, 't/data/rendered/run_list_basic.xml'), 'SequenceScape service with commas');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run.xml',
           REQUEST_METHOD => 'GET',
           username       => 'public',
           util           => $util,
           cgi_params     => {
            id_run => q[11|12|14|95],
                 },
          });

  ok($util->test_rendered($str, 't/data/rendered/run_list_basic.xml'), 'SequenceScape service with pipes');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run.xml',
           REQUEST_METHOD => 'GET',
           username       => 'public',
           util           => $util,
           cgi_params     => {
                 id_run         => [11,12,14,95],
                 },
          });

  ok($util->test_rendered($str, 't/data/rendered/run_list_basic.xml'), 'SequenceScape service with list');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run/recent/running/runs.xml',
           REQUEST_METHOD => 'GET',
           username       => 'joe_r_n_d',
           util           => $util,
          });
  ok($util->test_rendered($str, 't/data/rendered/run/recent/running/runs_basic_days.xml'), '/run/recent/running/runs.xml - basic days');
}

{
  my $model = npg::model::run->new({
                 util   => $util,
                 id_run => q(),
                });
  $model->{days} = 4000;
  my $view = npg::view::run->new({
          util  => $util,
          model => $model,
          action => 'list',
          aspect => 'list_recent_running_runs_xml',
         });
  my $str;
  lives_ok { $str = $view->render(); } 'no croak in render list_recent_running_runs_xml';
  ok($util->test_rendered($str, 't/data/rendered/run/recent/running/runs_4000_days.xml'), '/run/recent/running/runs.xml - 4000 days');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run/95',
           REQUEST_METHOD => 'GET',
           username       => 'public',
           util           => $util,
          });
  like ($str, qr/NPG SeqQC/, 'run with a current status --analysis complete-- contains the NPG-SeqQC link');
  like ($str, qr/checks\/runs\/95/, 'href value of the NPG-SeqQC link');
}


{
  my $str = t::request->new({
           PATH_INFO      => '/run/13',
           REQUEST_METHOD => 'GET',
           username       => 'public',
           util           => $util,
          });
  unlike ($str, qr/NPG SeqQC/, 'run with a current status --run in progress-- does not contain SeqQC link');
}

{
  my $id_run = 5;
  my $url = '/run/' . $id_run;
  my $str = t::request->new({
           PATH_INFO      => $url,
           REQUEST_METHOD => 'GET',
           username       => 'public',
           util           => $util,
          });
  like ($str, qr/team 'RAD'/, 'R&D team name displayed');
  like ($str, qr/<th>Loaded\ by<\/th><td\ id=\"loader_username\">joe_admin<\/td>/, 'run loader username displayed');
  like ($str, qr/<div\ id=\"verify_fc_div\"><img\ src=\"\/icons\/silk\/cross\.png\"/, 'flowcell marked as not verified');
  
  my $run = npg::model::run->new({id_run => $id_run, util => $util,});
  my $user = npg::model::user->new({id_user => 3, util => $util,});
  $run->save_tags(['verified_fc'], $user);
  $str = t::request->new({
           PATH_INFO      => $url,
           REQUEST_METHOD => 'GET',
           username       => 'public',
           util           => $util,
          });
  like ($str, qr/<div\ id=\"verify_fc_div\">joe_loader/, 'flowcell verified by correct user');
  like ($str, qr/<div\ id=\"verify_r1_div\"><img\ src=\"\/icons\/silk\/cross\.png\"/, 'reagents for read 1 marked as not verified');

  $user = npg::model::user->new({id_user => 4, util => $util,});
  $run->save_tags(['verified_r1'], $user);
  $str = t::request->new({
           PATH_INFO      => $url,
           REQUEST_METHOD => 'GET',
           username       => 'public',
           util           => $util,
          });
  like ($str, qr/<div\ id=\"verify_r1_div\">joe_engineer/, 'read1 reagents verified by correct user');
}

{
  my $mock    = {
    q(SELECT id_user FROM user WHERE username = ?:,public) => [[1]],
    q(SELECT id_usergroup FROM usergroup WHERE groupname = ?:,public) => [[]],
    q(SELECT ug.id_usergroup, ug.groupname, ug.is_public, ug.description, uug.id_user_usergroup FROM usergroup ug, user2usergroup uug WHERE uug.id_user = ? AND ug.id_usergroup = uug.id_usergroup:1) => [{}],
  };

  my $cgi = CGI->new();
  $util    = t::util->new({
          mock => $mock,
          cgi  => $cgi,
         });
  my $view = npg::view::run->new({
          util  => $util,
          model => npg::model::run->new({
                 util   => $util,
                 id_run => q(),
                }),
         });
  is($view->selected_days(), 14, '$view->selected_days() gives default 14 days if not set as cgi param');
  $cgi = $view->util->cgi();
  $cgi->param('days', 7);
  is($view->selected_days(), 7, '$view->selected_days() gives selected days if set as cgi param');
}

1;
