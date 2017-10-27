use strict;
use warnings;
use Test::More tests => 3;
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

1;