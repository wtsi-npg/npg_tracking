#########
# Author:        mg8
# copied from: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/instrument_handling/branches/prerelease-16.0/t/10-srpipe-runner-staging.t, r17037
#

use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;
use Cwd;

use_ok('npg_tracking::daemon::staging');
{
    my $r = npg_tracking::daemon::staging->new();
    isa_ok($r, 'npg_tracking::daemon::staging');
    is($r->daemon_name, 'staging_area_monitor', 'daemon name');

}

my $script = 'staging_area_monitor';

{
    my $hostname = q[sf2-nfs];
    my $log_dir = q[/nfs/sf2/staging_daemon_logs];

    my $r = npg_tracking::daemon::staging->new(timestamp => '2013', hosts => ['sf2-nfs', 'sf3-nfs']);
    throws_ok {$r->command} qr/Need host name/, 'error generating staging area path';
    throws_ok {$r->command('somesf3_nfs')}
      qr/Host name somesf3_nfs does not follow expected pattern sfXX-nfs/,
      'error generating staging area path';
    is($r->command('sf2-nfs'), "$script /export/sf2", 'command to run');

    is($r->host_to_sfarea($hostname), 2, 'get sf area from host');
    throws_ok {$r->host_to_sfarea('seq3')}
      qr/Host name seq3 does not follow expected pattern sfXX-nfs/,
      'error generating staging area path';

    throws_ok {$r->start($hostname)} qr/does not exist/ , 'start command notices missing staging log directory';
}

{
    my $hostname = q[sf18-nfs];
    my $log_dir = q[/nfs/sf18/staging_daemon_logs];

    my $r = npg_tracking::daemon::staging->new(timestamp => '2013', hosts => [$hostname]);
    is($r->start($hostname), qq[daemon -i -r -a 10 -n staging_area_monitor --umask 002 -A 10 -L 10 -M 10 -o $log_dir/staging_area_monitor-sf18-nfs-2013.log -- $script /export/sf18], 'start command');
    is($r->ping, q[daemon --running -n staging_area_monitor && ((if [ -w /tmp/staging_area_monitor.pid ]; then touch -mc /tmp/staging_area_monitor.pid; fi) && echo -n 'ok') || echo -n 'not ok'], 'ping command');
    is($r->stop, q[daemon --stop -n staging_area_monitor], 'stop command');
    is($r->log_dir($hostname), $log_dir, q[log directory is not set per host]);
}

1;
