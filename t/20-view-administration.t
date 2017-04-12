use strict;
use warnings;
use Test::More tests => 33;
use Test::Exception;
use t::util;

use_ok('npg::model::administration');
use_ok('npg::view::administration');
my $util  = t::util->new({fixtures => 1, cgi => CGI->new() });
my $cgi = $util->cgi();

{
  my $view = npg::view::administration->new({
               util   => $util,
               model  => npg::model::administration->new({util => $util,}),
               action => q{list},
               aspect => q{},
              });

  $util->requestor('public');
  my $render;
  lives_ok { $render = $view->render() };
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_list_public.html'),
    'display for public renders ok');

  $util->requestor('joe_engineer');
  lives_ok { $render = $view->render() };
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_list_engineers.html'),
    'display for engineers renders ok');

  $util->requestor('joe_admin');
  lives_ok { $render = $view->render() };
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_list_admin.html'),
    'display for admin renders ok');
}

{
  my $view = npg::view::administration->new({
               util   => $util,
               model  => npg::model::administration->new({util => $util,}),
               action => q{create},
               aspect => q{create_instrument_mod},
              });
  $util->requestor('public');
  throws_ok { $view->render() } qr{not\ authorised\ for\ this\ view },
    'create_instrument_mod not authorised for public';

  $view->aspect(q{create_instrument_status});
  throws_ok { $view->render() } qr{not\ authorised\ for\ this\ view },
    'create_instrument_status not authorised for public';
}

{
  $cgi->param('description','PE module');
  $cgi->param('revision', 'G');

  my $view = npg::view::administration->new({
               util   => $util,
               model  => npg::model::administration->new({util => $util,}),
               action => q{create},
               aspect => q{create_instrument_mod},
              });
  $util->requestor('joe_engineer');
  my $render;
  lives_ok { $render = $view->render(); }
    'engineers and admin authorised for create_instrument_mod';
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_create_instrument_mod.html'),
    'create_instrument_mod renders ok with description and revision');

  $cgi->param('description',q{});
  $cgi->param('new_description','filter');
  $cgi->param('revision', 'rgb');
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_instrument_mod},
  });
  lives_ok { $render = $view->render(); };
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_create_instrument_mod.html'),
    'create_instrument_mod renders ok with new_description and revision');

  $cgi->param('description',q{});
  $cgi->param('new_description',q{});
  $cgi->param('revision', 'rgb');
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_instrument_mod},
  });
  throws_ok {$view->render() } qr{description\ \(\)\ and\/or\ revision\ \(rgb\)\ is\ missing},
    'croaked - missing description';

  $cgi->param('description', 'present');
  $cgi->param('revision', q{});
  throws_ok { $view->render() } qr{description\ \(present\)\ and\/or\ revision\ \(\)\ is\ missing},
    'croaked - missing revision';
}

{
  $cgi->param('description',q{});
  my $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_instrument_status},
  });
  $util->requestor('joe_engineer');
  throws_ok { $view->render() } qr{No\ status\ given}, 'error - no status given';

  $cgi->param('description','new status');
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_instrument_status},
  });
  my $render;
  lives_ok { $render = $view->render() }
    'engineers and admin authorised for create_instrument_status';
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_create_instrument_status.html'),
    'create_instrument_status renders ok');
}

{
  $cgi->param('username',q{});
  my $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_user},
  });
  $util->requestor('joe_admin');
  throws_ok { $view->render() } qr{No\ username\ given}, 'error - no username given';

  $cgi->param('username','test');
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_user},
  });
  my $render;
  lives_ok { $render = $view->render() } 'admin authorised for create_user';
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_create_user.html'),
    'create_user renders ok');
}

{
  $cgi->param('description','test');
  $cgi->param('groupname',q{});
  $cgi->param('is_public', 0);
  my $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_usergroup},
  });
  $util->requestor('joe_admin');
  throws_ok { $view->render() } qr{No\ groupname\ and\/or\ group\ description\ given},
    'croaked - no groupname given';

  $cgi->param('description',q{});
  $cgi->param('groupname','test');
  $cgi->param('is_public', 0);
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_usergroup},
  });
  throws_ok { $view->render() } qr{No\ groupname\ and\/or\ group\ description\ given},
    'error - no description given';

  $cgi->param('description','test');
  $cgi->param('groupname','test');
  $cgi->param('is_public', 0);
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_usergroup},
  });
  my $render;
  lives_ok { $render = $view->render() } 'admin authorised for create_usergroup';
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_create_usergroup.html'),
    'create_usergroup renders ok');
}

{
  $cgi->param('description',q{});
  my $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_run_status},
  });
  $util->requestor('joe_admin');
  throws_ok { $view->render() } qr{No\ status\ given}, 'error - no status given';

  $cgi->param('description','test');
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_run_status},
  });
  my $render;
  lives_ok { $render = $view->render() } 'admin authorised for create_run_status';
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_create_run_status.html'),
    'create_run_status renders ok');
}

{
  $cgi->param('id_user',q{});
  $cgi->param('id_usergroup',1);

  my $view = npg::view::administration->new({
               util   => $util,
               model  => npg::model::administration->new({util => $util,}),
               action => q{create},
               aspect => q{create_user_to_usergroup},
              });
  $util->requestor('joe_admin');
  throws_ok { $view->render() } qr{No\ user\ and\/or\ usergroup\ given},
    'error - no user given';

  $cgi->param('id_user',1);
  $cgi->param('id_usergroup',q{});
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_user_to_usergroup},
  });
  throws_ok { $view->render() } qr{No\ user\ and\/or\ usergroup\ given},
    'error - no usergroup given';

  $cgi->param('id_user',2);
  $cgi->param('id_usergroup',2);
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_user_to_usergroup},
  });
  my $render;
  lives_ok { $render = $view->render() } 'admin authorised for create_usergroup';
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_create_usergroup.html'),
    'create_usergroup renders ok');
}

1;
