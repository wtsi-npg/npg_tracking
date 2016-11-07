use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;
use t::util;
use t::request;

use_ok 'npg::model::instrument_status';
use_ok 'npg::view::instrument_status';

my $util = t::util->new({fixtures => 1});

{
  my $str = t::request->new({
    PATH_INFO      => '/instrument_status/11',
    REQUEST_METHOD => 'POST',
    username       => 'joe_annotator',
    util           => $util,
  });
  like($str, qr{not\ authorised}mx, 'annotator access to update');
}

{
  my $str = t::request->new({
    PATH_INFO      => '/instrument_status/11',
    REQUEST_METHOD => 'POST',
    username       => 'joe_engineer',
    util           => $util,
  });
  like($str, qr{not\ authorised}mx, 'engineer access to update');
}

{
  my $model = npg::model::instrument_status->new({util => $util});
  my $cgi   = $util->cgi();
  $cgi->param('id_instrument', 8);
  $cgi->param('id_instrument_status_dict', 5);
  my $view  = npg::view::instrument_status->new({
    util   => $util,
    model  => $model,
    action => 'create',
    aspect => '',
  });

  throws_ok { $view->render(); }
    qr{Status \"request approval\" is deprecated},
    'error as status is depreceted';

  $cgi->param('id_instrument_status_dict', 11);
  my $render;
  lives_ok { $render = $view->render(); } 'no error on render of create';
  ok($util->test_rendered($render, 't/data/rendered/20-view-instrument_status-update.html'),
    'render of create ok for correct movement between statuses');
}

1;
