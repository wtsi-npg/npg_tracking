use strict;
use warnings;
use Test::More tests => 6;
use t::util;
use npg::model::tag;
use npg::model::run;

my $util = t::util->new({
       fixtures => 1,
      });
{
  my $run = npg::model::run->new({
          util   => $util,
          id_run => 1,
         });
  my $tags = $run->tags();
  is((scalar @{$tags}), 1, 'number of tags');
  is($tags->[0]->tag(), '2G', 'tag contents');
}

{
  my $run = npg::model::run->new({
          util   => $util,
          id_run => 1,
         });

  ok($run->save_tags(['my_test_tag']), 'save_tags');

  my $tags = $run->tags();
  is((scalar @{$tags}), 2, 'number of tags');
}

{
  my $run = npg::model::run->new({
          util   => $util,
          id_run => 1,
         });

  ok($run->remove_tags(['my_test_tag']), 'remove_tags');

  my $tags = $run->tags();
  is((scalar @{$tags}), 1, 'number of tags');
}

1;
