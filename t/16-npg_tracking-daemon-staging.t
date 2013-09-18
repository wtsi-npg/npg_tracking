#########
# Author:        mg8
# copied from: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/instrument_handling/branches/prerelease-16.0/t/10-srpipe-runner-staging.t, r17037
#

use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;
use Cwd;

use_ok('npg_tracking::daemon::staging');
{
    my $r = npg_tracking::daemon::staging->new();
    isa_ok($r, 'npg_tracking::daemon::staging');
}

{
    my $log_dir = join q[/],getcwd(), 'logs';
    my $script = 'staging_area_monitor';
    my $r = npg_tracking::daemon::staging->new(timestamp => '2013', hosts => ['sf2-nfs', 'sf3-nfs']);
    throws_ok {$r->command} qr/Need host name/, 'error generating staging area path';
    throws_ok {$r->command('somesf3_nfs')}
      qr/Host name somesf3_nfs does not follow expected pattern sfXX-nfs/,
      'error generating staging area path';
    is($r->command('sf2-nfs'), "$script /export/sf2", 'command to run');
    is($r->daemon_name, 'staging_area_monitor', 'daemon name');
    is($r->start(q[sf2-nfs]), qq[daemon -i -r -a 10 -n staging_area_monitor --umask 002 -A 10 -L 10 -M 10 -o $log_dir/staging_area_monitor-sf2-nfs-2013.log -- $script /export/sf2], 'start command');
    is($r->ping, q[daemon --running -n staging_area_monitor && echo -n 'ok' || echo -n 'not ok'], 'ping command');
    is($r->stop, q[daemon --stop -n staging_area_monitor], 'stop command');
}
1;

