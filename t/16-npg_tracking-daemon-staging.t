#########
# Author:        mg8
# copied from: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/instrument_handling/branches/prerelease-16.0/t/10-srpipe-runner-staging.t, r17037
#

use strict;
use warnings;
use Test::More tests => 10;
use Test::Exception;
use Cwd;

use_ok(q[npg_tracking::daemon::staging]);
{
    my $r = npg_tracking::daemon::staging->new();
    isa_ok($r, q[npg_tracking::daemon::staging]);
}

{
    my $log_dir = join q[/],getcwd(), q[logs];
    my $script = q[staging_area_monitor];
    my $r = npg_tracking::daemon::staging->new(timestamp => q[2013], hosts => [q[sf2-nfs], q[sf3-nfs]]);
    throws_ok {$r->command} qr/Need host name/, q[error generating staging area path];
    throws_ok {$r->command(q[somesf3_nfs])}
      qr/Host name somesf3_nfs does not follow expected pattern sfXX-nfs/,
      q[error generating staging area path];
    is($r->command(q[sf2-nfs]), "$script /export/sf2", q[command to run]);
    is($r->daemon_name, q[staging_area_monitor], q[daemon name]);
    throws_ok {$r->start(q[sf2-nfs]) }  qr/used for the log for this daemon does not exist/, q[no staging_log directory for non-existent host]; 
    is($r->ping, q[daemon --running -n staging_area_monitor && ((if [ -w /tmp/staging_area_monitor.pid ]; then touch -mc /tmp/staging_area_monitor.pid; fi) && echo -n 'ok') || echo -n 'not ok'], q[ping command]);
    is($r->stop, q[daemon --stop -n staging_area_monitor], 'stop command');
}

{ 
    my $log_dir = q[/nfs/sf18/staging_logs];
    my $script = q[staging_area_monitor];
    my $r = npg_tracking::daemon::staging->new(timestamp => '2013', hosts => ['sf18-nfs']);
    is($r->start(q[sf18-nfs]), qq[daemon -i -r -a 10 -n staging_area_monitor --umask 002 -A 10 -L 10 -M 10 -o $log_dir/staging_area_monitor-sf18-nfs-2013.log -- $script /export/sf18], q[start command with new log location]);
}

1;

