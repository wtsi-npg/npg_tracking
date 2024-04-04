use strict;
use warnings;
use Test::More tests => 29;
use Test::Exception;
use Test::Deep;
use CGI;
use Cwd;

BEGIN {
  local $ENV{'HOME'}=getcwd().'/t';
  use_ok('npg::view::run');
};

# We need to ensure that npg::view::run is the first npg
# module loaded
use_ok('t::util');
use_ok('t::request');

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
  my $default_urls = {'npg_tracking' => 'http://some.san.ac.uk:678',
                      'seqqc'        => 'http://some.san.ac.uk:999'};
  my $esa_urls = {'npg_tracking'  => 'http://esa-sv.dnap.san.ac.uk:678',
                  'seqqc'         => 'http://esa-sv.dnap.san.ac.uk:999'};
  is_deeply($view->staging_urls(),  $default_urls,
    'no args, default urls returned');
  is_deeply($view->staging_urls('host'),  $default_urls,
    'no match args, default urls returned');
  is_deeply($view->staging_urls('esa-sv'),  $esa_urls,
    'matching host args, correct host-specific urls returned');

  my $name = 'esa-sv-20180707';
  $esa_urls = {'npg_tracking'  => qq[http://${name}.dnap.san.ac.uk:678],
               'seqqc'         => qq[http://${name}.dnap.san.ac.uk:999]};
  is_deeply($view->staging_urls($name), $default_urls,
    'default urls - no run id, so not on staging');

  $view = npg::view::run->new({
          util  => $util,
          model => npg::model::run->new({
                 util   => $util,
                 id_run => 8,
                }),
         });
  is_deeply($view->staging_urls($name), $esa_urls, 'run on staging, esa urls');
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
  like ($str, qr/Loaded\ by\ joe_admin/, 'run loader username displayed');
}

{
  my $mock    = {
    q(SELECT id_user FROM user WHERE username = ?:,public) => [[1]],
    q(SELECT id_usergroup FROM usergroup WHERE groupname = ?:,public) => [[]],
    q(SELECT ug.id_usergroup, ug.groupname, ug.is_public, ug.description, ug.iscurrent, uug.id_user_usergroup FROM usergroup ug, user2usergroup uug WHERE uug.id_user = ? AND ug.iscurrent = 1 AND ug.id_usergroup = uug.id_usergroup:1) => [{}],
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
