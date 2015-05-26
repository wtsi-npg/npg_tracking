use strict;
use warnings;
use Test::More tests => 12;
use Test::Exception;

BEGIN {
   local $ENV{'HOME'} = q[];
   use_ok('npg_tracking::daemon::status');
}

my $script = 'npg_status_watcher';

{
    my $s = npg_tracking::daemon::status->new();
    isa_ok($s, 'npg_tracking::daemon::status');
    is($s->daemon_name, $script, 'daemon name');
    throws_ok {$s->_local_prefix}
      qr/Failed to get path prefix/,
      'no cong file - error retrieving local prefix';
    throws_ok {$s->hosts}
      qr/Failed to get list of indexes for staging areas/,
      'no cong file - error retrieving hosts';
}

{
    my $local_prefix = q[/export/sf];
    my $s = npg_tracking::daemon::status->new(_local_prefix => $local_prefix);
    is($s->command(), $script, 'command to run');
    is($s->host_name2path(q[sf2-nfs]), $local_prefix.q[2], 'local staging path');
    throws_ok {$s->host_name2path('seq')}
      qr/Host name seq does not follow expected pattern/,
      'error generating staging area path';

    my $hostname = q[sf18-nfs];
    my $log_dir = $local_prefix.q[18/log];
    my $bash_command = qq([[ -d $log_dir && -w $log_dir ]] && );
    my $bash_error_command = qq( || echo Log directory $log_dir for staging host sf18-nfs cannot be written to);

    $s = npg_tracking::daemon::status->new(
      _local_prefix => $local_prefix, timestamp => '2013', hosts => [$hostname]);
    is($s->log_dir($hostname), $log_dir, q[log directory is set per host]);
    is($s->start($hostname), $bash_command . qq[daemon -i -r -a 10 -n $script --umask 002 -A 10 -L 10 -M 10 -o $log_dir/${script}-sf18-nfs-2013.log -- $script] . $bash_error_command , 'start command');
    is($s->ping, q{daemon --running -n } . $script . q{ && ((if [ -w /tmp/} . $script . q{.pid ]; then touch -mc /tmp/} . $script. q[.pid; fi) && echo -n 'ok') || echo -n 'not ok'], 'ping command');
    is($s->stop, qq[daemon --stop -n $script], 'stop command');
}

1;
