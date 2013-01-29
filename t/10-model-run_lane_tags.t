#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-03-11
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-run_lane_tags.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-run_lane_tags.t $
#
use strict;
use warnings;
use Test::More tests => 6;
use t::util;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

my $util  = t::util->new({fixtures => 1});

use_ok('npg::model::tag');
use_ok('npg::model::tag_run_lane');

{
  my $model = npg::model::tag_run_lane->new({
					     util            => $util,
					     id_tag_run_lane => 1,
					    });
  is($model->id_user(), 5, 'load without init');
}

{
  my $model = npg::model::tag_run_lane->new({
					     util            => $util,
					     id_tag          => 9,
					    });
  is($model->id_user(), undef, 'impossible load');
}

{
  my $model = npg::model::tag_run_lane->new({
					     util            => $util,
					     id_run_lane     => 5,
					     id_tag          => 9,
					    });
  is($model->id_user(), 5, 'load with init');
}

{
  my $model = npg::model::tag_run_lane->new({
					     util            => $util,
					     id_tag_run_lane => 1,
					     id_run_lane     => 5,
					     id_tag          => 9,
					    });
  is($model->id_user(), 5, 'populated load without init');
}

1;
