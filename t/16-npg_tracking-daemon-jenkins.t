use strict;
use warnings;
use Test::More tests => 14;
use Test::Exception;
use File::Temp qw/tempdir/;
use File::Slurp;
use Cwd;

use npg_tracking::util::abs_path qw(abs_path);

use_ok('npg_tracking::daemon::jenkins');
my $tmpdir = tempdir( CLEANUP => 1 );
my $current_dir = abs_path getcwd();
{
  local $ENV{'HOME'} = q[];
  my $j = npg_tracking::daemon::jenkins->new();
  isa_ok($j, 'npg_tracking::daemon::jenkins');

  throws_ok { $j->jenkins_war } qr/User home is not defined/,
    'error if $HOME is not defined';

  local $ENV{'HOME'} = $tmpdir;
  throws_ok { $j->jenkins_war }
    qr/Attribute \(jenkins_war\) does not pass the type constraint/,
    'jenkins war file does not exist';
}

{
  local $ENV{'HOME'}         = $tmpdir;
  local $ENV{'JENKINS_HOME'} = q{};
  my $jvar = "${tmpdir}/jenkins.war";
  write_file( $jvar, qw/some data/ ) ;

  my $r = npg_tracking::daemon::jenkins->new(timestamp => '20130419-144441');
  $r->clear_session_timeout; # Unset the default timeout to test base command

  is_deeply($r->env_vars, {'http_proxy' => q[http://wwwcache.sanger.ac.uk:3128]},
      'http proxy environment variable set correctly');
  is(join(q[ ], @{$r->hosts}), q[sf2-farm-srv2], 'list of hosts');
  is($r->command('host1'), qq[java -Xmx2g  -Dhttp.proxyHost=wwwcache.sanger.ac.uk -Dhttp.proxyPort=3128 -jar $jvar --httpPort=9960 --logfile=${current_dir}/logs/jenkins_host1_20130419-144441.log], 'command to run');
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

  is($r->command('host1'), qq[java -Xmx2g -Djava.io.tmpdir=/does/not/exist/tmp -Dhttp.proxyHost=wwwcache.sanger.ac.uk -Dhttp.proxyPort=3128 -jar $jvar --httpPort=9960 --logfile=${current_dir}/logs/jenkins_host1_20130419-144441.log], 'command to run');
}
1;
