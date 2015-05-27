use strict;
use warnings;
use Test::More tests => 15;
use Test::Exception;
use List::MoreUtils qw/all/;

BEGIN {
    local $ENV{'HOME'} = 't';
    use_ok('npg_tracking::daemon::staging');
}

my $script = 'staging_area_monitor';
{
    my $d = npg_tracking::daemon::staging->new();
    isa_ok($d, 'npg_tracking::daemon::staging');
    is($d->daemon_name, $script, 'daemon name');
    is($d->_local_prefix, q[/nfs/sf]);
    is($d->_prefix, q[sf]);
    my @hosts = @{$d->hosts};
    is(scalar @hosts, 36, 'correct number of hosts');
    my $correct = all { $_ =~ m{\Asf\d\d-nfs\Z} } @hosts;
    ok($correct, 'correct host name pattern'); 
}

{
    my $hostname = q[gs02-nfs];
    my $local_prefix = q[/nfs/gs];
    my $r = npg_tracking::daemon::staging->new(
      _local_prefix => $local_prefix, timestamp => '2013', hosts => [$hostname, 'sf3-nfs']);
    throws_ok {$r->command} qr/Need host name/, 'error generating staging area path';
    throws_ok {$r->command('somesf_nfs')}
      qr/Host name somesf_nfs does not follow expected pattern/,
      'error generating staging area path';
    is($r->host_name2path($hostname), qq[${local_prefix}02], 'get path prefix from host name');
    is($r->command($hostname), qq[$script ${local_prefix}02], 'command to run');
}

{
    my $hostname = q[sf18-nfs];
    my $local_prefix = q[/nfs/sf];
    my $log_dir = $local_prefix . q[18/log];
    my $bash_command = qq([[ -d $log_dir && -w $log_dir ]] && );
    my $bash_error_command = qq( || echo Log directory $log_dir for staging host sf18-nfs cannot be written to);

    my $r = npg_tracking::daemon::staging->new(
      _local_prefix => $local_prefix, timestamp => '2013', hosts => [$hostname]);
    is($r->log_dir($hostname), $log_dir, q[log directory is set per host]);
    is($r->start($hostname), $bash_command . qq[daemon -i -r -a 10 -n staging_area_monitor --umask 002 -A 10 -L 10 -M 10 -o $log_dir/staging_area_monitor-sf18-nfs-2013.log -- $script $local_prefix] . q[18] . $bash_error_command , 'start command');
    is($r->ping, q[daemon --running -n staging_area_monitor && ((if [ -w /tmp/staging_area_monitor.pid ]; then touch -mc /tmp/staging_area_monitor.pid; fi) && echo -n 'ok') || echo -n 'not ok'], 'ping command');
    is($r->stop, q[daemon --stop -n staging_area_monitor], 'stop command');
}

1;
