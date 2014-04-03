use strict;
use warnings;
use Test::More tests => 12;
use Test::Deep;
use Cwd;

use_ok('npg_tracking::daemon::jenkins');

{
  my $r = npg_tracking::daemon::jenkins->new();
  isa_ok($r, 'npg_tracking::daemon::jenkins');
}

{
  local $ENV{'JENKINS_HOME'} = q{};

  my $r = npg_tracking::daemon::jenkins->new(timestamp => '20130419-144441');
  $r->clear_session_timeout; # Unset the default timeout to test base command

  is_deeply($r->env_vars, {'http_proxy' => q[http://wwwcache.sanger.ac.uk:3128]},
      'http proxy environment variable set correctly');
  is(join(q[ ], @{$r->hosts}), q[sf2-farm-srv2], 'list of hosts');
  is($r->command('host1'), qq[java -Xmx2g  -Dhttp.proxyHost=wwwcache.sanger.ac.uk -Dhttp.proxyPort=3128 -jar ~srpipe/jenkins.war --httpPort=9960 --logfile=]. getcwd() .q[/logs/jenkins_host1_20130419-144441.log], 'command to run');
  is($r->daemon_name, 'npg_jenkins', 'daemon name');
  is($r->ping, q[daemon --running -n npg_jenkins && ((if [ -w /tmp/npg_jenkins.pid ]; then touch -mc /tmp/npg_jenkins.pid; fi) && echo -n 'ok') || echo -n 'not ok'], 'ping command');
  is($r->stop, q[daemon --stop -n npg_jenkins], 'stop command');
  my $start_command = $r->start('host1');
  like($start_command, qr/jenkins.war --httpPort=9960/, 'the command contains jar file and port');

  # Test optional CLI arguments
  like(npg_tracking::daemon::jenkins->new
       (timestamp => '20130419-144441')->command('host1'),
       qr/--sessionTimeout=\d+/, 'Default session timeout is present');

  my $supplied_timeout = 60;
  like(npg_tracking::daemon::jenkins->new
       (timestamp       => '20130419-144441',
        session_timeout => $supplied_timeout)->command('host1'),
       qr/--sessionTimeout=$supplied_timeout/,
       'Non-zero session timeout is set');

  local $ENV{'JENKINS_HOME'} = q{/does/not/exist};

  is($r->command('host1'), qq[java -Xmx2g -Djava.io.tmpdir=/does/not/exist/tmp -Dhttp.proxyHost=wwwcache.sanger.ac.uk -Dhttp.proxyPort=3128 -jar ~srpipe/jenkins.war --httpPort=9960 --logfile=]. getcwd() .q[/logs/jenkins_host1_20130419-144441.log], 'command to run');
}
1;
