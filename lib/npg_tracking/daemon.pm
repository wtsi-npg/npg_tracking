package npg_tracking::daemon;


use Moose;
use namespace::autoclean;
use Sys::Hostname;
use POSIX   qw(strftime);
use FindBin qw($Bin);
use List::MoreUtils qw(any);
use Readonly;

use npg_tracking::util::abs_path qw(abs_path);
use npg_tracking::util::config   qw(get_config_users);

our $VERSION = '0';

## no critic (RequireInterpolationOfMetachars)
Readonly::Scalar my $DEFAULT_COMMAND => q{perl -e '$|=1;while(1){print "daemon running\n";sleep5;}'};
## use critic

=head1 NAME

npg_tracking::daemon

=head1 SYNOPSIS

=head1 DESCRIPTION

A base class for wrappers that keep metadata about running
an arbitrary script as a daemon on a remote server.

=head1 SUBROUTINES/METHODS

=cut

=head2 libs

A array ref of lib paths to use in the PERL5LIB

=cut
has 'libs'        =>  (isa             => 'Maybe[ArrayRef]',
                       is              => 'ro',
                       required        => 0,
                      );

=head2 env_vars

A hash reference with arbitrary environment variables and their values
which should be passed to the script running as a daemon

=cut
has 'env_vars'    =>  (isa             => 'Maybe[HashRef]',
                       is              => 'ro',
                       required        => 0,
                       lazy_build      => 1,
                      );
sub _build_env_vars {
    return;
}

=head2 hosts

A reference to a list of hosts.

=cut
has 'hosts' =>        (isa             => 'ArrayRef',
                       is              => 'ro',
                       required        => 0,
                       lazy_build      => 1,
                      );
sub _build_hosts {
  return [hostname];
}

=head2 timestamp

timestamp, is used in the name of the log file

=cut
has 'timestamp' =>    (isa             => 'Str',
                       is              => 'ro',
                       default         => sub {strftime '%Y%m%d-%H%M%S', localtime time},
                      );

=head2 log_dir

Directory where the log file is created, defaults to 'logs' parallel to the current bin

=cut
sub log_dir {
    my ($self, $host) = @_;
    return abs_path "$Bin/../logs";
}

sub _class_name {
    my $self = shift;
    my ($ref) = (ref $self) =~ /(\w*)$/smx;
    return $ref;
}

=head2 start

Command to start a script, as a string.

=cut
sub start {
    my ($self, $host) = @_;
    $host ||= hostname;
    my $perl5lib = q[];
    if (defined $self->libs) {
        $perl5lib = join q[:], @{$self->libs};
    }

    my $log_dir = $self->log_dir($host);
    my $test = q{[[ -d } . $log_dir . q{ && -w } . $log_dir . q{ ]] && };
    my $error = q{ || echo Log directory } .  $log_dir . q{ for staging host } . $host . q{ cannot be written to};
    my $action = $test . q[daemon -i -r -a 10 -n ] . $self->daemon_name;
    if ($perl5lib) {
        $action .= qq[ --env=\"PERL5LIB=$perl5lib\"];
    }
    if ($self->env_vars) {
        while ((my $var, my $value) = each %{$self->env_vars}) {
            $action .= qq[ --env=\"$var=$value\"];
        }
    }

    my $script_call = $self->command($host);
    my $log_path_prefix = join q[/], $log_dir, $self->daemon_name;
    return $action . q[ --umask 002 -A 10 -L 10 -M 10 -o ] . $log_path_prefix . qq[-$host] . q[-]. $self->timestamp() . q[.log ] . qq[-- $script_call] . $error;
}

=head2 ping

Command to ping a running script, as a string.

=cut
sub ping {
    my $self = shift;
    my $dname = $self->daemon_name;
    my $pid_file = q[/tmp/] . $dname . q[.pid];
    return qq[daemon --running -n $dname && ((if [ -w $pid_file ]; then touch -mc $pid_file; fi) && echo -n 'ok') || echo -n 'not ok'];
}

=head2 stop

Command to stop a running script, as a string.

=cut
sub stop {
    my $self = shift;
    return q[daemon --stop -n ] .$self->daemon_name;
}

=head2 command

Command to run. By default a perl one-liner printing a string to standard out every 5 sec.
To be overwritten by inheriting class.

=cut
sub command {
    return $DEFAULT_COMMAND;
}

=head2 daemon_name

Default value of the daemon name - class name.

=cut
sub daemon_name {
    my $self = shift;
    return $self->_class_name;
}

=head2 is_prod_user

Retrieves a list of known production users from the tracking configuration
file and validates the given user. Returns true if the user is given and
is production user, otherwise returns false. Can be called both as a class
and instance method.

  $obj->is_prod_user('myuser');
  __PACKAGE__->is_prod_user('myuser');

=cut
sub is_prod_user {
  my ($self, $user) = @_;

  my $result = 0;
  if ($user) {
    my $h = get_config_users();
    if( $h->{'production'} ) {
      $result = any { $_ eq $user} @{$h->{'production'}};
    }
  }
  return $result;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Readonly

=item Sys::Hostname

=item POSIX

=item FindBin

=item List::MoreUtils

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL, by Marina Gourtovaia

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




