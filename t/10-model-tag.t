#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-03-03
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-tag.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-tag.t $
#
use strict;
use warnings;
use English qw(no_match_vars);
use t::util;
use Test::More tests => 10;

use_ok('npg::model::tag');

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 14928 $ =~ /(\d+)/mx; $r; };

my $util = t::util->new({
       fixtures => 1,
      });

{
  my $tag = npg::model::tag->new({
          util => $util,
         });
  isa_ok($tag, 'npg::model::tag');
}

{
  my $tag = npg::model::tag->new({
          util => $util,
          tag  => '2G',
         });
  is($tag->id_tag(), 1, 'load by tag');
}

{
  my $tag = npg::model::tag->new({
          util   => $util,
          id_tag => 1,
         });
  is($tag->tag(), '2G', 'load by id');
}

{
  my $tag = npg::model::tag->new({
          util   => $util,
          id_tag => 1,
         });
  my $all_tags = $tag->all_tags();
  is((scalar @{$all_tags}), 16, 'unprimed cache - all tags');
  is((scalar @{$tag->all_tags()}), 16, 'primed cache - all tags');

  my $runs = $tag->runs();
  is((scalar @{$runs}), 4, 'unprimed cache - runs');
  is((scalar @{$tag->runs}), 4, 'primed cache - runs');
}

{
  my $tag = npg::model::tag->new({
          util   => $util,
          id_tag => 2,
         });
  my $run_lanes = $tag->run_lanes();
  is((scalar @{$run_lanes}), 1, 'unprimed cache - run_lanes');
  is((scalar @{$tag->run_lanes()}), 1, 'primed cache - run_lanes');
}

1;
