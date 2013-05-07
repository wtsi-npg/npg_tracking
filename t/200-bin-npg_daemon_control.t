use strict;
use warnings;
use IPC::Open2;
use Perl6::Slurp;
use Test::More tests => 50;

my $command = 'bin/npg_daemon_control 2>&1';
 # or with handle autovivification
my($chld_out, $chld_in);
my $pid = open2($chld_out, $chld_in, $command);
waitpid( $pid, 0 );
my $child_exit_status = $? >> 8;
is ($child_exit_status, 0, 'no error running bin/npg_daemon_control');

my @lines = slurp $chld_out;

like (shift(@lines), qr/npg_daemon_control options:/, 'correct first line of help');
like (shift(@lines), qr/--help/, 'help option present');
like (shift(@lines), qr/--dry-run/, 'dry-run option present');

foreach my $app (qw/jenkins samplesheet staging/) {
  foreach my $action (qw/ping stop start/) {
    my $option = q{--} . $action . q{_} . $app;
    like (shift(@lines), qr/$option/, qq{option $option present});

    my $cmd = qq{bin/npg_daemon_control --dry-run $option 2>&1};
    my($child_out, $child_in);
    my $prid = open2($child_out, $child_in, $cmd);
    waitpid( $prid, 0 );
    my $cexit_status = $? >> 8;
    is ($cexit_status, 0, qq{no error running $cmd});
    my $out = slurp $child_out;
    like ($out, qr/DRY RUN/, 'output marked as dry run');
    like ($out, qr/command to be executed:/, 'command to be executed label present');
    like ($out, qr/command:/, 'command label present');
  }
}

like (shift @lines, qr/--host/, 'host option present');

1;
