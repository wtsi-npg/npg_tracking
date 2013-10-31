#########
# Author:        Keith James
# Created:       2013-10-31
# copied from: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/instrument_handling/trunk/lib/srpipe/runner/jenkins.pm, r17056
#

package npg_tracking::daemon::jenkins_precise;

use Moose;
use Carp;
use English qw(-no_match_vars);
use Readonly;

extends 'npg_tracking::daemon';

Readonly::Scalar our $JENKINS_WAR    => q[~srpipe/jenkins.war];
Readonly::Scalar our $JENKINS_HOME   => q[/local/scratch01/npg_jenkins];
Readonly::Scalar our $JENKINS_LOGDIR => q[/local/scratch01/srpipe_logs];
Readonly::Scalar our $JENKINS_PORT   => 9960;

Readonly::Scalar our $PROXY_SERVER => q[wwwcache.sanger.ac.uk];
Readonly::Scalar our $PROXY_PORT   => 3128;
Readonly::Scalar our $COMMAND => qq[java -Xmx2g -DJENKINS_HOME=$JENKINS_HOME -Dhttp.proxyHost=$PROXY_SERVER -Dhttp.proxyPort=$PROXY_PORT -jar $JENKINS_WAR --httpPort=$JENKINS_PORT];

override '_build_hosts' => sub { return ['sf2-farm-srv1']; };
override '_build_env_vars' => sub { return {'http_proxy' => qq[http://$PROXY_SERVER:$PROXY_PORT]}; };
override 'command'  => sub {
  my $self = shift;
  my $log_name = join q[.], q[jenkins], $self->timestamp(), q[log];
  return join q[ ], $COMMAND, "--logfile=$JENKINS_LOGDIR/$log_name";
};
override 'daemon_name'  => sub { return 'npg_jenkins'; };


no Moose;

1;
__END__

=head1 NAME

npg_tracking::daemon::jenkins_precise

=head1 SYNOPSIS

=head1 DESCRIPTION

Metadata for a daemon that starts up a Jenkins integration server on
Ubuntu Precise.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>
        Keith James E<lt>kdj@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013 GRL, by Marina Gourtovaia

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut




