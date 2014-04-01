use strict;
use warnings;
use Test::More tests => 19;
use English qw(-no_match_vars);
use t::util;
use npg::model::instrument_mod;

use_ok('npg::view::instrument_mod');
my $util = t::util->new({ fixtures => 1, cgi => CGI->new() });
{
  $util->requestor('public');

  my $view = npg::view::instrument_mod->new({
               util   => $util,
               action => 'list',
               aspect => q{},
               model  => npg::model::instrument_mod->new({
                      util => $util,
                           }),
              });
  my $render;
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on render for public');
  ok($util->test_rendered($render, 't/data/rendered/instrument_mod_list_public.html'), 'list for public renders ok');
  $util->requestor('joe_engineer');
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on render for engineer');
  ok($util->test_rendered($render, 't/data/rendered/instrument_mod_list_engineer.html'), 'list for engineers renders ok');
}

{
  my $cgi = $util->cgi();
  $cgi->param('id_instrument_mod_dict', 1);
  $cgi->param('id_instrument', 3);
  $cgi->param('iscurrent', 1);
  $cgi->param('remove', 1);
  $util->requestor('public');

  my $view = npg::view::instrument_mod->new({
               util   => $util,
               action => 'create',
               aspect => q{},
               model  => npg::model::instrument_mod->new({
                      util => $util,
                           }),
              });
  isa_ok($view, 'npg::view::instrument_mod');
  eval { $view->render(); };
  like($EVAL_ERROR, qr/not\ authorised/mx, 'croak as not authorised for create');
  $view->action('update');
  eval { $view->render(); };
  like($EVAL_ERROR, qr/not\ authorised/mx, 'croak as not authorised for update');
  $view->action('read');
  $view->aspect('add_ajax');
  eval { $view->render(); };
  like($EVAL_ERROR, qr/not\ authorised/mx, 'croak as not authorised for add_ajax');
  $view->aspect('create_xml');
  eval { $view->render(); };
  like($EVAL_ERROR, qr/not\ authorised/mx, 'croak as not authorised for create_xml');
}

{
  my $cgi = $util->cgi();
  $cgi->param('id_instrument_mod_dict', 1);
  $cgi->param('id_instrument', 3);
  $cgi->param('iscurrent', 1);
  $cgi->param('remove', 1);
  $util->requestor('joe_engineer');
  my $view = npg::view::instrument_mod->new({
               util   => $util,
               action => 'create',
               aspect => q{},
               model  => npg::model::instrument_mod->new({
                      util => $util,
                           }),
              });
  eval { $view->render(); };
  is($EVAL_ERROR, q{}, 'engineers authorised for create');
  $view->action('update');
  eval { $view->render(); };
  is($EVAL_ERROR, q{}, 'engineers authorised for update');
  $cgi->param('remove',0);
  eval { $view->render(); };
  like($EVAL_ERROR, qr{removal\ not\ set}, 'croaks as remove not set');
  $view->action('create');
  $view->aspect('add_ajax');
  ok($view->authorised(), 'engineers authorised for add_ajax');
  ok($util->test_rendered($view->render(), 't/data/rendered/20-view-instrument_mod_add_ajax.html'), 'add_ajax renders ok');
}

$util = t::util->new({ fixtures => 1, cgi => CGI->new() });
{
  my $cgi = $util->cgi();
  $cgi->param('id_instrument_mod_dict', 1);
  $cgi->param('id_instrument', 3);
  $cgi->param('iscurrent', 1);
  $cgi->param('remove', 1);
  $util->requestor('pipeline');
  my $view = npg::view::instrument_mod->new({
               util   => $util,
               action => 'create',
               aspect => 'create_xml',
               model  => npg::model::instrument_mod->new({
                      util => $util,
                           }),
              });
  my $render;
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'create_xml and pipeline member');
  ok($util->test_rendered($render, 't/data/rendered/20-view-instrument_mod_read_xml.xml'), 'create_xml renders ok');
}

$util = t::util->new({ fixtures => 1, cgi => CGI->new() });
{
  my $cgi = $util->cgi();
  $util->requestor('joe_admin');
  $cgi->param('id_instrument',(3,4));
  $cgi->param('id_instrument_mod_dict',6);
  $cgi->param('iscurrent',1);

  my $view = npg::view::instrument_mod->new({
               util   => $util,
               action => 'create',
               aspect => 'update_mods',
               model  => npg::model::instrument_mod->new({
                      util => $util,
                           }),
              });
  my $render = $view->render();
  is($EVAL_ERROR, qq{}, 'no croak on batch update of mods');
  ok($util->test_rendered($render, 't/data/rendered/20-view-instrument_mod_batch_update.html'), 'batch update renders ok');
}

1;
