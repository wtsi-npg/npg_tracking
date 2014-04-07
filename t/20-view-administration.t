use strict;
use warnings;
use English qw(-no_match_vars);
use t::util;
use npg::model::administration;

use Test::More tests => 31;

use_ok('npg::view::administration');
my $util  = t::util->new({fixtures => 1, cgi => CGI->new() });

{
  my $view = npg::view::administration->new({
               util   => $util,
               model  => npg::model::administration->new({
                      util => $util,
                           }),
               action => q{list},
               aspect => q{},
              });

  $util->requestor('public');
  my $render;
  eval { $render = $view->render(); };
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_list_public.html'), 'display for public renders ok');

  $util->requestor('joe_engineer');
  eval { $render = $view->render(); };
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_list_engineers.html'), 'display for engineers renders ok');

  $util->requestor('joe_admin');
  eval { $render = $view->render(); };
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_list_admin.html'), 'display for admin renders ok');
}

{
  my $view = npg::view::administration->new({
               util   => $util,
               model  => npg::model::administration->new({
                      util => $util,
                           }),
               action => q{create},
               aspect => q{create_instrument_mod},
              });
  $util->requestor('public');
  my $render;
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{not\ authorised\ for\ this\ view }, 'create_instrument_mod not authorised for public');

  $view->aspect(q{create_instrument_status});
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{not\ authorised\ for\ this\ view }, 'create_instrument_status not authorised for public');
}

{
  my $cgi = $util->cgi();
  $cgi->param('description','PE module');
  $cgi->param('revision', 'G');

  my $view = npg::view::administration->new({
               util   => $util,
               model  => npg::model::administration->new({
                      util => $util,
                           }),
               action => q{create},
               aspect => q{create_instrument_mod},
              });
  $util->requestor('joe_engineer');
  my $render;
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'engineers and admin authorised for create_instrument_mod');
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_create_instrument_mod.html'), 'create_instrument_mod renders ok with description and revision');

  $cgi->param('description',q{});
  $cgi->param('new_description','filter');
  $cgi->param('revision', 'rgb');
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_instrument_mod},
  });
  eval { $render = $view->render(); };
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_create_instrument_mod.html'), 'create_instrument_mod renders ok with new_description and revision');

  $cgi->param('description',q{});
  $cgi->param('new_description',q{});
  $cgi->param('revision', 'rgb');
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_instrument_mod},
  });
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{description\ \(\)\ and\/or\ revision\ \(rgb\)\ is\ missing}, 'croaked - missing description');
  $cgi->param('description', 'present');
  $cgi->param('revision', q{});
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{description\ \(present\)\ and\/or\ revision\ \(\)\ is\ missing}, 'croaked - missing revision');
}

{
  my $cgi = $util->cgi();
  $cgi->param('description',q{});
  my $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_instrument_status},
  });
  $util->requestor('joe_engineer');
  my $render;
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{No\ status\ given}, 'croaked - no status given');
  $cgi->param('description','new status');
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_instrument_status},
  });
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'engineers and admin authorised for create_instrument_status');
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_create_instrument_status.html'), 'create_instrument_status renders ok');
}

{
  my $cgi = $util->cgi();
  $cgi->param('username',q{});
  my $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_user},
  });
  $util->requestor('joe_admin');
  my $render;
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{No\ username\ given}, 'croaked - no username given');
  $cgi->param('username','test');
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_user},
  });
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'admin authorised for create_user');
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_create_user.html'), 'create_user renders ok');
}

{
  my $cgi = $util->cgi();
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
  my $render;
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{No\ groupname\ and\/or\ group\ description\ given}, 'croaked - no groupname given');
  $cgi->param('description',q{});
  $cgi->param('groupname','test');
  $cgi->param('is_public', 0);
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_usergroup},
  });
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{No\ groupname\ and\/or\ group\ description\ given}, 'croaked - no description given');
  $cgi->param('description','test');
  $cgi->param('groupname','test');
  $cgi->param('is_public', 0);
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_usergroup},
  });
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'admin authorised for create_usergroup');
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_create_usergroup.html'), 'create_usergroup renders ok');
}

{
  my $cgi = $util->cgi();
  $cgi->param('description',q{});
  $cgi->param('iscurrent',1);
  my $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_entity_type},
  });
  $util->requestor('joe_admin');
  my $render;
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{No\ entity\ type\ given}, 'croaked - no entity type given');
  $cgi->param('description','test');
  $cgi->param('iscurrent',1);
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_entity_type},
  });
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'admin authorised for create_entity_type');
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_create_entity_type.html'), 'create_entity_type renders ok');
}

{
  my $cgi = $util->cgi();
  $cgi->param('description',q{});
  my $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_run_status},
  });
  $util->requestor('joe_admin');
  my $render;
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{No\ status\ given}, 'croaked - no status given');
  $cgi->param('description','test');
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_run_status},
  });
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'admin authorised for create_run_status');
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_create_run_status.html'), 'create_run_status renders ok');
}

{
  my $cgi = $util->cgi();
  $cgi->param('id_user',q{});
  $cgi->param('id_usergroup',1);

  my $view = npg::view::administration->new({
               util   => $util,
               model  => npg::model::administration->new({
                      util => $util,
                           }),
               action => q{create},
               aspect => q{create_user_to_usergroup},
              });
  $util->requestor('joe_admin');

  my $render;
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{No\ user\ and\/or\ usergroup\ given}, 'croaked - no user given');
  $cgi->param('id_user',1);
  $cgi->param('id_usergroup',q{});
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_user_to_usergroup},
  });
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{No\ user\ and\/or\ usergroup\ given}, 'croaked - no usergroup given');

  $cgi->param('id_user',2);
  $cgi->param('id_usergroup',2);
  $view = npg::view::administration->new({
    util => $util,
    model => npg::model::administration->new({ util => $util }),
    action => q{create},
    aspect => q{create_user_to_usergroup},
  });
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'admin authorised for create_usergroup');
  ok($util->test_rendered($render, 't/data/rendered/20-view-administration_create_usergroup.html'), 'create_usergroup renders ok');
}

1;
