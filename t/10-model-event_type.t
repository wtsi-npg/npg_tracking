#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-01-11
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-event_type.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-event_type.t $
#

use strict;
use warnings;
use t::util;
use Test::More tests => 4;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

use_ok('npg::model::event_type');

my $util = t::util->new({fixtures => 1});

{
  my $model = npg::model::event_type->new({
					   id_event_type => 1,
                                           util          => $util,
                                          });
  my $events = $model->events();
  is((scalar @{$events}), 7, 'number of events');
}

{
  my $model = npg::model::event_type->new({
					   id_entity_type => 6,
					   description    => 'status change',
                                           util           => $util,
                                          });
  my $events = $model->events();
  is((scalar @{$events}), 7, 'load by description + id+entity_type');
}

{
  my $model = npg::model::event_type->new({
					   id_event_type => 1,
                                           util          => $util,
                                          });
  my $usergroups = $model->usergroups();
  is((scalar @{$usergroups}), 1, 'number of usergroups');
}

1;
