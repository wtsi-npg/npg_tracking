#########
# Author:        mg8
# Created:       18 December 2009
# copied from: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/instrument_handling/branches/prerelease-16.0/t/10-srpipe-runner-qsea.t, r16149
#

use strict;
use warnings;
use Test::More tests => 9;
use Test::Deep;
use Cwd;

use_ok('npg_tracking::daemon::jenkins');
{
    my $r = npg_tracking::daemon::jenkins->new();
    isa_ok($r, 'npg_tracking::daemon::jenkins');
}

{
    my $r = npg_tracking::daemon::jenkins->new(timestamp => '20130419-144441');    
    is_deeply($r->env_vars, {'http_proxy' => q[http://wwwcache.sanger.ac.uk:3128]},
      'http proxy environment variable set correctly');
    is(join(q[ ], @{$r->hosts}), q[sf-4-1-02 sf2-farm-srv1], 'list of hosts');
    is($r->command('host1'), q[java -Xmx2g -Dhttp.proxyHost=wwwcache.sanger.ac.uk -Dhttp.proxyPort=3128 -jar ~srpipe/jenkins.war --httpPort=9960 --logfile=]. getcwd() .q[/logs/jenkins_host1_20130419-144441.log], 'command to run');
    is($r->daemon_name, 'npg_jenkins', 'daemon name');
    is($r->ping, q[daemon --running -n npg_jenkins && echo -n 'ok' || echo -n 'not ok'], 'ping command');
    is($r->stop, q[daemon --stop -n npg_jenkins], 'stop command');
    my $start_command = $r->start('host1');
    like($start_command, qr/jenkins.war --httpPort=9960/, 'the command contains jar file and port');
}

1;
