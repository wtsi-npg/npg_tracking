use strict;
use warnings;
use t::util;
use Test::More tests => 3;

use_ok('npg::model::event_type');

my $util = t::util->new({fixtures => 1});

my $model = npg::model::event_type->new({id_event_type => 1,
                                         util          => $util,
                                        });
is((scalar @{$model->events()}), 7, 'number of events');

$model = npg::model::event_type->new({id_entity_type => 6,
                                      description    => 'status change',
                                      util           => $util,
                                     });
is((scalar @{$model->events()}), 7, 'load by description + id+entity_type');

1;
