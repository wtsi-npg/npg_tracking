use strict;
use warnings;
use Test::More tests => 4;

use_ok('npg_tracking::daemon::elembiostaging');
my $d = npg_tracking::daemon::elembiostaging->new();
isa_ok($d, 'npg_tracking::daemon::elembiostaging');
is ($d->daemon_name, 'elembio_staging_area_monitor', 'daemon name is correct');
is ($d->command,
  'elembio_staging_area_monitor --staging_area /lustre/scratch120/elembio/staging',
  'command to execute is correct');

1;

