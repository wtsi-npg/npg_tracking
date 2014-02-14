#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-03-06
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-run_tags.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-run_tags.t $
#
use strict;
use warnings;
use Test::More tests => 6;
use t::util;
use npg::model::tag;
use npg::model::run;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

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
