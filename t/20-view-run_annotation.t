use strict;
use warnings;
use Test::More tests => 3;
use English qw(-no_match_vars);
use t::util;
use t::request;

use_ok('npg::view::run_annotation');

my $util = t::util->new({
       fixtures => 1,
      });
{
  my $str = t::request->new({
           PATH_INFO      => '/run_annotation;add_ajax',
                             REQUEST_METHOD => 'GET',
                             username       => 'public',
                             util           => $util,
           cgi_params     => {
            id_run => 42,
                 },
                            });
  like($str, qr/not\ authorised/smx, 'public add_ access');
}

{
  my $str = t::request->new({
           PATH_INFO      => '/run_annotation;add_ajax',
                             REQUEST_METHOD => 'GET',
                             username       => 'joe_annotator',
                             util           => $util,
           cgi_params     => {
            id_run => 42,
                 },
                            });
  ok($util->test_rendered($str, 't/data/rendered/run_annotation_add_ajax.html'), 'add_ajax render');
}
1;
