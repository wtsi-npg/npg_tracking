#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-01-09
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-entity_type.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-entity_type.t $
#

use strict;
use warnings;
use t::util;
use Test::More tests => 9;
use Test::Trap;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

use_ok('npg::model::entity_type');

my $util = t::util->new({fixtures => 1});

{
  my $model = npg::model::entity_type->new({
              util           => $util,
              id_entity_type => 1,
             });
  isa_ok($model, 'npg::model::entity_type');

  my $events = $model->events();
  is((scalar @{$events}), 3, 'unprimed cache number of events');
  is((scalar @{$model->events()}), 3, 'primed cache number of events');

  my $cet = $model->current_entity_types();
  is((scalar @{$cet}), 10, 'unprimed cache current_entity_types');
  is((scalar @{$model->current_entity_types()}), 10, 'primed cache current_entity_types');

  my $all = $model->entity_types();
  is((scalar @{$all}), 13, 'unprimed cache entity_types');
}

{
  my $model = npg::model::entity_type->new({
              util        => $util,
              description => 'run',
             });
  is($model->id_entity_type(), 1, 'load by description');
}

{
  trap {
    my $model = npg::model::entity_type->new({
                util        => 'bla',
                description => 'fail!',
               });
    is($model->init(), undef, 'database query failure');
  };
}

1;
