#########
# Author:        mg8
# Created:       18 December 2009
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/instrument_handling/branches/prerelease-16.0/t/10-srpipe-runner-samplesheet.t, r15259
#

use strict;
use warnings;
use Test::More tests => 9;
use Test::Deep;
use Cwd;

use_ok('npg_tracking::daemon::samplesheet');
{
    my $r = npg_tracking::daemon::samplesheet->new();
    isa_ok($r, 'npg_tracking::daemon::samplesheet');
}

{
    my $perl = $^X;
    my $perl5lib = $ENV{PERL5LIB};
    my $log_dir = join(q[/],getcwd(), 'logs');
    my $r = npg_tracking::daemon::samplesheet->new(timestamp => '2013');
    ok(scalar(@{$r->libs}) > 0, 'libs defined');
    is($r->hosts->[0], q[sf-4-1-02], 'default host name');
    is($r->command, $perl . q[ -e 'use strict; use warnings; use npg::samplesheet::auto;  use Log::Log4perl qw(:easy); BEGIN{ Log::Log4perl->easy_init({level=>$INFO,}); } npg::samplesheet::auto->new()->loop();'], 'command to run');
    is($r->daemon_name, 'npg_samplesheet_daemon', 'default daemon name');
    is($r->start(q[sf-1-1-01]), qq[daemon -i -r -a 10 -n npg_samplesheet_daemon --env="PERL5LIB=$perl5lib" --umask 002 -A 10 -L 10 -M 10 -o $log_dir/npg_samplesheet_daemon-] . qq[sf-1-1-01-2013.log -- $perl ] . q[-e 'use strict; use warnings; use npg::samplesheet::auto;  use Log::Log4perl qw(:easy); BEGIN{ Log::Log4perl->easy_init({level=>$INFO,}); } npg::samplesheet::auto->new()->loop();'], 'start command');
    is($r->ping, q[daemon --running -n npg_samplesheet_daemon && echo -n 'ok' || echo -n 'not ok'], 'ping command');
    is($r->stop, q[daemon --stop -n npg_samplesheet_daemon], 'stop command');
}
