use strict;
use warnings;
use Test::More tests => 15;
use Sys::Hostname;
use Cwd;

my $hostname = hostname;
my $timestamp = '20130417-133635';
my $log_dir = join(q[/],getcwd(), 'logs');

use_ok('npg_tracking::daemon');
my $default_command = q{perl -e '$|=1;while(1){print "daemon running\n";sleep5;}'};
my $command = q{perl -e '$|=1;while(1){print "daemon running\n";sleep5;}' || echo Log directory } . $log_dir . q{ for staging host } . $hostname . q{ cannot be written to};
{
    my $r = npg_tracking::daemon->new();
    isa_ok($r, 'npg_tracking::daemon');
}

{
    my $r = npg_tracking::daemon->new(timestamp=>$timestamp);
    is($r->libs, undef, 'libs undef by default');
    is($r->hosts->[0], $hostname, 'default host name is this host');
    is($r->command, $default_command, 'default command');
    is($r->daemon_name, 'daemon', 'default daemon name');

    is($r->start($hostname), qq([[ -d $log_dir && -w $log_dir ]] && daemon -i -r -a 10 -n daemon --umask 002 -A 10 -L 10 -M 10 -o $log_dir/daemon-) . $hostname . qq[-$timestamp.log -- $command], 'start command on local host');
    is($r->ping($hostname), q[daemon --running -n daemon && ((if [ -w /tmp/daemon.pid ]; then touch -mc /tmp/daemon.pid; fi) && echo -n 'ok') || echo -n 'not ok'], 'ping command on local host');
    is($r->stop($hostname), q[daemon --stop -n daemon], 'stop command on local host');

    is($r->start(), qq([[ -d $log_dir && -w $log_dir ]] && daemon -i -r -a 10 -n daemon --umask 002 -A 10 -L 10 -M 10 -o $log_dir/daemon-) . $hostname . qq[-$timestamp.log -- $command], 'start command with an undefined host');
    is($r->ping(), q[daemon --running -n daemon && ((if [ -w /tmp/daemon.pid ]; then touch -mc /tmp/daemon.pid; fi) && echo -n 'ok') || echo -n 'not ok'], 'ping command with an undefined host');
    is($r->stop(), q[daemon --stop -n daemon], 'stop command with an undefined host');
}

{
    my $hostname = q[sf18-nfs];
    my $command = q{perl -e '$|=1;while(1){print "daemon running\n";sleep5;}' || echo Log directory } . $log_dir . q{ for staging host } . $hostname . q{ cannot be written to};

    my $r = npg_tracking::daemon->new(timestamp => $timestamp,
                                      libs      => ['/dodo/lib1', '/dada/lib2'],
                                      hostname => $hostname,
                                     );
    is($r->start($hostname), qq([[ -d $log_dir && -w $log_dir ]] && daemon -i -r -a 10 -n daemon --env="PERL5LIB=/dodo/lib1:/dada/lib2" --umask 002 -A 10 -L 10 -M 10 -o $log_dir/daemon-$hostname-$timestamp.log -- $command), 'start command on local host');
  
    $hostname = hostname;
    $command = q{perl -e '$|=1;while(1){print "daemon running\n";sleep5;}' || echo Log directory } . $log_dir . q{ for staging host } . $hostname . q{ cannot be written to};

    $r = npg_tracking::daemon->new(timestamp=>$timestamp,env_vars => {http_proxy=>'myproxy',});
    is($r->start(), qq([[ -d $log_dir && -w $log_dir ]] && daemon -i -r -a 10 -n daemon --env="http_proxy=myproxy" --umask 002 -A 10 -L 10 -M 10 -o $log_dir/daemon-) . $hostname . qq[-$timestamp.log -- $command], 'start command with an undefined host when PERL5LIB should be set');

    $r = npg_tracking::daemon->new(timestamp=>$timestamp,
                                   libs => ['/dodo/lib1', '/dada/lib2'],
                                   env_vars => {http_proxy=>'myproxy',});
    is($r->start(), qq([[ -d $log_dir && -w $log_dir ]] && daemon -i -r -a 10 -n daemon --env="PERL5LIB=/dodo/lib1:/dada/lib2" --env="http_proxy=myproxy" --umask 002 -A 10 -L 10 -M 10 -o $log_dir/daemon-) . $hostname . qq[-$timestamp.log -- $command], 'start command with an undefined host when PERL5LIB should be set'); 
}
1;
