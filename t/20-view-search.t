use strict;
use warnings;
use Test::More tests => 4;
use t::util;
use t::request;
use npg::model::search;

use_ok('npg::view::search');

my $util = t::util->new({
       fixtures => 1,
      });

{
  my $str = t::request->new({
                             PATH_INFO      => '/search',
                             REQUEST_METHOD => 'GET',
           username       => 'public',
                             util           => $util,
           cgi_params     => {
            query => 'TriosP',
                 },
                            });
  ok($util->test_rendered($str, 't/data/rendered/search.html'), 'list render');
}

{
  my $str = t::request->new({
                             PATH_INFO      => '/search',
                             REQUEST_METHOD => 'GET',
           username       => 'public',
                             util           => $util,
           cgi_params     => {
            query => '  TriosP',
                 },
                            });
  ok($util->test_rendered($str, 't/data/rendered/search.html'), 'list render leading whitespace');
}

{
  my $str = t::request->new({
                             PATH_INFO      => '/search',
                             REQUEST_METHOD => 'GET',
           username       => 'public',
                             util           => $util,
           cgi_params     => {
            query => 'TriosP ',
                 },
                            });
  ok($util->test_rendered($str, 't/data/rendered/search.html'), 'list render trailing whitespace');
}

1;
