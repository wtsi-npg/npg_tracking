use strict;
use warnings;
use Test::More tests => 2;
use t::util;
use t::request;

my $util = t::util->new({fixtures => 1});

{
  my $str = t::request->new({
           util           => $util,
           username       => 'public',
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/run_status_dict.xml',
          });
  $str =~ s/.*?\n\n//smx;
  ok($util->test_rendered($str, 't/data/rendered/run_status_dict.xml'), 'run_status_dict list_xml');
}

{
  my $str = t::request->new({
           util           => $util,
           username       => 'public',
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/run_status_dict/2.xml',
          });

  $str =~ s/.*?\n\n//smx;
  ok($util->test_rendered($str, 't/data/rendered/run_status_dict/2.xml'), 'run_status_dict read_xml');
}
