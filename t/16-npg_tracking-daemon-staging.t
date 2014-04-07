use strict;
use warnings;
use Test::More tests => 14;
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
    my $root_dir = q[/nfs];

    my $r = npg_tracking::daemon::staging->new(root_dir => $root_dir, timestamp => '2013', hosts => ['sf2-nfs', 'sf3-nfs']);
    is($r->root_dir, $root_dir, 'supplied root directory is used');
    throws_ok {$r->command} qr/Need host name/, 'error generating staging area path';
    throws_ok {$r->command('somesf3_nfs')}
      qr/Host name somesf3_nfs does not follow expected pattern sfXX-nfs/,
      'error generating staging area path';
    is($r->command('sf2-nfs'), qq[$script $root_dir/sf2], 'command to run');

    is($r->_host_to_sfarea($hostname), qq[$root_dir/sf2], 'get sf area from host');
    throws_ok {$r->_host_to_sfarea('seq3')}
      qr/Host name seq3 does not follow expected pattern sfXX-nfs/,
      'error generating staging area path';
}

{
    my $hostname = q[sf18-nfs];
    my $root_dir = q[/export];

    my $r = npg_tracking::daemon::staging->new(timestamp => '2013', hosts => [$hostname]);
    is($r->root_dir, $root_dir, 'default root directory is correct');
}

{
    my $hostname = q[sf18-nfs];
    my $root_dir = q[/nfs];
    my $log_dir = qq[$root_dir/sf18/staging_daemon_logs];
    my $bash_command = q([[ -d /nfs/sf18/staging_daemon_logs && -w /nfs/sf18/staging_daemon_logs ]] && );
    my $bash_error_command = q( || echo Log directory /nfs/sf18/staging_daemon_logs for staging host sf18-nfs cannot be written to);

    my $r = npg_tracking::daemon::staging->new(root_dir => $root_dir, timestamp => '2013', hosts => [$hostname]);
    is($r->start($hostname), $bash_command . qq[daemon -i -r -a 10 -n staging_area_monitor --umask 002 -A 10 -L 10 -M 10 -o $log_dir/staging_area_monitor-sf18-nfs-2013.log -- $script $root_dir/sf18] . $bash_error_command , 'start command');
    is($r->ping, q[daemon --running -n staging_area_monitor && ((if [ -w /tmp/staging_area_monitor.pid ]; then touch -mc /tmp/staging_area_monitor.pid; fi) && echo -n 'ok') || echo -n 'not ok'], 'ping command');
    is($r->stop, q[daemon --stop -n staging_area_monitor], 'stop command');
    is($r->log_dir($hostname), $log_dir, q[log directory is set per host]);
}

1;
