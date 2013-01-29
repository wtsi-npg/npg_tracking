#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-01-09
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-event.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-event.t $
#

use strict;
use warnings;
use t::util;
use npg::model::user;
use Test::More tests => 7;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

use_ok('npg::model::event');

my $util = t::util->new({fixtures => 1});

{
  my $model = npg::model::event->new({
                                      util  => $util,
                                     });
  isa_ok($model, 'npg::model::event');
}

{
  my $run = npg::model::run->new({ util => $util, id_run => 1 });
  my $model = npg::model::event->new({
				      util           => $util,
				      id_event_type  => 1,
				      description    => 'test event_type_id',
				      entity_id      => 1,
				      id_user        => 1,
				      run            => $run,
				      status_description => 'run complete',
				     });

  ok($model->create(), 'event->create with id_ev_t');
}

{
  my $model = npg::model::event->new({
				      util           => $util,
				      id_entity_type => 6,
				      entity_type_description => 'run_status',
				      id_event_type  => 1,
				      description    => 'test entity id + desc',
				      entity_id      => 1,
				      id_user        => 1,
				     });

  ok($model->create(), 'event->create with entity id & description');
}

{
  my $model = npg::model::event->new({
				      util           => $util,
				      id_event_type  => 1,
				      event_type_description => 'status change',
				      id_entity_type => 9,
				      description    => 'a test with event id + desc',
				      entity_id      => 1,
				      id_user        => 1,
				     });

  ok($model->create(), 'event->create with event id & desc');
}

{
  my $model = npg::model::event->new({
				      util          => $util,
				      id_event_type => 1,
				      description   => 'a test',
				      entity_id     => 1,
				      date          => '2008-04-11 17:52:00',
				     });

  my $requestor = npg::model::user->new({
					 util    => $util,
					 id_user => 2,
					});
  $util->requestor($requestor);
  ok($model->create(), 'event->create with requestor');
}

{
  my $run = npg::model::run->new({ util => $util, id_run => 3948});
  my $model = npg::model::event->new({
				      util           => $util,
				      id_event_type  => 1,
				      description    => 'batch with multiplexed lane',
				      entity_id      => 1,
				      id_user        => 1,
				      run            => $run,
				      status_description => 'run complete',
				     });
  ok($model->create(), 'event->create with id_ev_t');
}

1;
