use strict;
use warnings;
use Test::More tests => 11;
use t::util;
use t::request;

my $util = t::util->new({fixtures => 1,});

{
  my $str = t::request->new({
           PATH_INFO      => '/instrument_format',
           REQUEST_METHOD => 'GET',
           username       => 'public',
           util           => $util,
          });
  ok($util->test_rendered($str,  't/data/rendered/menus/instruments_formats.html'),
    'menu instruments>formats');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument_utilisation',
           username       => 'public',
           util           => $util,
          });
  ok($util->test_rendered($str, 't/data/rendered/menus/instruments_utilisation_30days_textual.html'),
    'menu instruments>utilisation>30days-textual');

  $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument_utilisation/graphical',
           username       => 'public',
           util           => $util,
          });
  ok($util->test_rendered($str, 't/data/rendered/menus/instruments_utilisation_30days_barchart.html'),
    'menu instruments>utilisation>30days-barchart');

  $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument_utilisation/graphical/line',
           username       => 'public',
           util           => $util,
          });
  ok($util->test_rendered($str, 't/data/rendered/menus/instruments_utilisation_30days_lineplot.html'),
    'menu instruments>utilisation>30days-lineplot');

  $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument_utilisation/text90',
           username       => 'public',
           util           => $util,
          });
  ok($util->test_rendered($str, 't/data/rendered/menus/instruments_utilisation_90days_textual.html'),
    'menu instruments>utilisation>90days-textual');

  $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument_utilisation/graphical/line90',
           username       => 'public',
           util           => $util,
          });
  ok($util->test_rendered($str, 't/data/rendered/menus/instruments_utilisation_90days_lineplot.html'),
    'menu instruments>utilisation>90days_lineplot');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument;list_graphical',
           username       => 'public',
           util           => $util,
          });

  ok($util->test_rendered($str, 't/data/rendered/menus/instruments_status_graphical.html'),
    'menu instruments>status>graphical');

  $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument;list_textual',
           username       => 'public',
           util           => $util,
          });
  ok($util->test_rendered($str, 't/data/rendered/menus/instruments_status_textual.html'),
    'menu instruments>status>textual');
}

{
  use_ok('npg::model::instrument_mod');
  $util->requestor(q(joe_loader));
  my $view = npg::view::instrument_mod->new({
               util   => $util,
               action => 'list',
               aspect => q{},
               model  => npg::model::instrument_mod->new({util => $util,}),
              }); 
  ok($util->test_rendered($view->render(), 't/data/rendered/menus/instruments_make_change_mods.html'),
    'menu instruments>make_change>mods');

  my $str = t::request->new({
           PATH_INFO      => '/instrument/edit_statuses',
           REQUEST_METHOD => 'GET',
           username       => 'joe_loader',
           util           => $util,
          });
  ok($util->test_rendered($str,  't/data/rendered/menus/instruments_make_change_statuses.html'),
    'menu instruments>make_change>edit_statuses');
}

1;