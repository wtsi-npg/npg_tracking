use strict;
use warnings;
use Test::More tests => 10;
use English qw(-no_match_vars);
use t::util;
use t::request;
use npg::model::run;

use_ok('npg::view::run');

my $util = t::util->new({
       fixtures => 1,
      });

{
  my $str = t::request->new({
           util           => $util,
           username       => 'public',
           PATH_INFO      => '/run/1;update_tags',
           REQUEST_METHOD => 'POST',
          });

  like($str, qr{not\ authorised}mx, 'not authorised to create tags if not admin');
}

{
  my $str = t::request->new({
           util           => $util,
           username       => 'joe_annotator',
           PATH_INFO      => '/run/1;update_tags',
           REQUEST_METHOD => 'POST',
          });
  ok($util->test_rendered($str, 't/data/rendered/run/1.html;update_tags-no-tags'), 'list render is ok - no tags added');
}

{
  my $str = t::request->new({
           util           => $util,
           username       => 'joe_annotator',
           PATH_INFO      => '/run/1;update_tags',
           REQUEST_METHOD => 'POST',
           cgi_params     => {
            tags           => 'good BAd',
            tagged_already => 'good',
                 },

          });

  ok($util->test_rendered($str, 't/data/rendered/run/1.html;update_tags'), 'list render is ok - tags added');

  my $run = npg::model::run->new({
          util   => $util,
          id_run => 1,
         });
  my $tags = $run->tags();
  is((scalar @{$tags}), 2,     'number of tags');
  is($tags->[0]->tag(), '2G',  'tag 1 content');
  is($tags->[1]->tag(), 'bad', 'tag 2 content');
}

{
  my $str = t::request->new({
           util           => $util,
           username       => 'joe_annotator',
           PATH_INFO      => '/run/1;update_tags',
           REQUEST_METHOD => 'POST',
           cgi_params     => {
            tags           => 'good',
            tagged_already => 'good bad',
                 },
          });
  ok($util->test_rendered($str, 't/data/rendered/run/1.html;update_tags'), 'list render is ok - tags removed');
  my $run = npg::model::run->new({
          util   => $util,
          id_run => 1,
         });
  my $tags = $run->tags();
  is((scalar @{$tags}), 1,    'number of tags');
  is($tags->[0]->tag(), '2G', 'tag 2 content');

}

1;
