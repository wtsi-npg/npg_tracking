use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;

my $script = 'npg_status_watcher';

use_ok('npg_tracking::daemon::status');
{
    my $s = npg_tracking::daemon::status->new();
    isa_ok($s, 'npg_tracking::daemon::status');
    is($s->daemon_name, $script, 'daemon name');
    my $root_dir = q[/export];
    my $hostname = q[sf2-nfs];
    is($s->root_dir, $root_dir, 'default root directory is correct');
    is($s->command(), $script, 'command to run');
    is($s->host_name2path($hostname), qq[$root_dir/sf2], 'get local staging path');
    throws_ok {$s->host_name2path('seq3')}
      qr/Host name seq3 does not follow expected pattern sfXX-nfs/,
      'error generating staging area path';

    $hostname = q[sf18-nfs];
    my $log_dir = qq[$root_dir/sf18/npg_status_watcher_logs];
    my $bash_command = qq([[ -d $log_dir && -w $log_dir ]] && );
    my $bash_error_command = qq( || echo Log directory $log_dir for staging host sf18-nfs cannot be written to);

    $s = npg_tracking::daemon::status->new(root_dir => $root_dir, timestamp => '2013', hosts => [$hostname]);
    is($s->log_dir($hostname), $log_dir, q[log directory is set per host]);
    is($s->start($hostname), $bash_command . qq[daemon -i -r -a 10 -n $script --umask 002 -A 10 -L 10 -M 10 -o $log_dir/${script}-sf18-nfs-2013.log -- $script] . $bash_error_command , 'start command');
    is($s->ping, q{daemon --running -n } . $script . q{ && ((if [ -w /tmp/} . $script . q{.pid ]; then touch -mc /tmp/} . $script. q[.pid; fi) && echo -n 'ok') || echo -n 'not ok'], 'ping command');
    is($s->stop, qq[daemon --stop -n $script], 'stop command');
}

1;
