use strict;
use warnings;
use Test::More tests => 13;
use English qw(-no_match_vars);
use t::util;
use t::request;
use npg::model::instrument_status;

use_ok('npg::view::instrument_status');

my $util = t::util->new({fixtures => 1});

{
  my $str = t::request->new({
    PATH_INFO      => '/instrument_status/up/down_xml',
    REQUEST_METHOD => 'GET',
    username       => 'public',
    util           => $util,
  });
  ok($util->test_rendered($str, 't/data/rendered/instrument_status/list_up_down_xml.xml'), 'render of list_up_down_xml ok for instruments');
}

{
  my $str = t::request->new({
    PATH_INFO      => '/instrument_status.xml',
    REQUEST_METHOD => 'POST',
    username       => 'public',
    util           => $util,
  });
  like($str, qr{not\ authorised}mx, 'public access to create_xml');
}

{
  my $str = t::request->new({
    PATH_INFO      => '/instrument_status.xml',
    REQUEST_METHOD => 'POST',
    username       => 'pipeline',
    util           => $util,
  });
  unlike($str, qr{not\ authorised}mx, 'pipeline access to create_xml');
}

{
  my $str = t::request->new({
    PATH_INFO      => '/instrument_status',
    REQUEST_METHOD => 'POST',
    username       => 'joe_annotator',
    util           => $util,
  });
  unlike($str, qr{not\ authorised}mx, 'annotator access to create_xml');
}

{
  my $str = t::request->new({
    PATH_INFO      => '/instrument_status',
    REQUEST_METHOD => 'POST',
    username       => 'joe_engineer',
    util           => $util,
  });
  unlike($str, qr{not\ authorised}mx, 'engineer access to create_xml');
}

{
  my $str = t::request->new({
    PATH_INFO      => '/instrument_status/11',
    REQUEST_METHOD => 'GET',
    username       => 'public',
    util           => $util,
  });
  unlike($str, qr{not\ authorised}mx, 'public access to read');
}

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
  my $render;
  
  $util->catch_email($model);
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{Instrument IL5 \"request approval\" status cannot follow current \"wash required\" status}, 'croaked as not correct order of assigning instrument statuses');

  $cgi->param('id_instrument_status_dict', 11);
  eval { $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on render of create');
  ok($util->test_rendered($render, 't/data/rendered/20-view-instrument_status-update.html'), 'render of create ok for correct movement between statuses');
  ok(! scalar @{ $model->{emails} }, 'no emails have been sent to alert of new status update');
}

1;
