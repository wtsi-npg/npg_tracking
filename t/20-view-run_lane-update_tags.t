use strict;
use warnings;
use Test::More tests => 4;
use t::util;
use t::request;

my $util = t::util->new({fixtures=>1});

{
  my $str = t::request->new({
           util           => $util,
           username       => 'public',
           REQUEST_METHOD => 'POST',
           PATH_INFO      => '/run_lane/1;update_tags',
          });

  like($str, qr{not\ authorised}smx, 'not authorised to create tags if not admin');
}

{
  my $str = t::request->new({
           util           => $util,
           username       => 'joe_annotator',
           REQUEST_METHOD => 'POST',
           PATH_INFO      => '/run_lane/1;update_tags',
           cgi_params     => {
                 },
          });

  ok($util->test_rendered($str, 't/data/rendered/run_lane/1;update_tags'), 'update tags without tags');
}

{
  my $str = t::request->new({
           util           => $util,
           username       => 'joe_annotator',
           REQUEST_METHOD => 'POST',
           PATH_INFO      => '/run_lane/1;update_tags',
           cgi_params     => {
            tags           => 'good BAd',
            tagged_already => 'good',
                 },
          });

  ok($util->test_rendered($str, 't/data/rendered/run_lane/1;update_tags'), 'update tags with tag addition');
}

{
  my $str = t::request->new({
           util           => $util,
           username       => 'joe_annotator',
           REQUEST_METHOD => 'POST',
           PATH_INFO      => '/run_lane/1;update_tags',
           cgi_params     => {
            tags           => 'good',
            tagged_already => 'good bad',
                 },
          });

  ok($util->test_rendered($str, 't/data/rendered/run_lane/1;update_tags'), 'update tags with tag removal');
}

1;
