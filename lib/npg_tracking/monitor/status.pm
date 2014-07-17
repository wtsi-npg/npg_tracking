package npg_tracking::monitor::status;

use Moose;
use Carp;
use English qw(-no_match_vars);
use Readonly;
use Linux::Inotify2;
use Errno qw(EINTR EIO :POSIX);

use npg_tracking::util::types;

our $VERSION = '0';

has 'dir'        =>   (isa             => 'NpgTrackingDirectory',
                       is              => 'ro',
                       required        => 1,
                      );

has '_notifier'  =>   (isa             => 'Linux::Inotify2',
                       is              => 'ro',
                       required        => 0,
                       init_arg        => undef,
                       lazy_build      => 1,
                      );
sub _build__notifier {
  my $inotify = Linux::Inotify2->new()
    or croak "unable to create new inotify object: $ERRNO";
  #watch is blocking by default
  #$inotify->blocking(); #remove blocking
  return $inotify;
}

has '_watch_obj'  =>  (isa             => 'HashRef',
                       is              => 'ro',
                       required        => 0,
                       init_arg        => undef,
                       default         => sub { {} },
                      );

sub _error {
  my ($self, $path, $error) = @_;
  $self->_cancel_watch();
  my $m;
  if      ($error == EBADF) {
    $m = q[The given file descriptor is not valid.];
  } elsif ($ERRNO == EINVAL) {
    $m = q[The given event mask contains no legal events.];
  } elsif ($ERRNO == ENOMEM) {
    $m = q[Insufficient kernel memory was available.];
  } elsif ($ERRNO == ENOSPC) {
    $m = q[The user limit on the total number of inotify watches was reached or the kernel failed to allocate a needed resource.];
  #} elsif ($ERRNO == EACCESS) {
  #  $m = q[Read access to the given file is not permitted.]; #  EACCESS is not recognised
  } else {
    $m = q[];
  }
  croak "Error when trying to set watch on $path: '$error' $m";
  return;
}

sub _runfolder_watch_setup {
  my ($self, $name) = @_;
  _log("runforder $name watch setup called");
  return;
}

sub _runfolder_watch_cancel {
  my ($self, $name) = @_;
  _log("runforder $name watch cancel called");
  return;
}


sub _watch_setup {
  my $self = shift;

  my $watch = $self->_notifier->watch($self->dir, IN_ISDIR | IN_UNMOUNT | IN_IGNORED | IN_MOVED_TO | IN_DELETE, sub {
      my $e = shift;
      my $name = $e->fullname;
      if ($e->IN_IGNORED) {
        croak "Events for $name have been lost";
      }
      if ($e->IN_UNMOUNT) {
        croak "Filesystem unmounted for $name";
      }
      if ($e->IN_DELETE) {
        _log("$name deleted");
        $self->_runfolder_watch_cancel($name);
      } elsif ($e->IN_MOVED_TO) {
        _log("$name moved to the watched directory");
        $self->_runfolder_watch_setup($name);
      }
  });

  if (!$watch) {
    my $err = $ERRNO;
    $self->_error($self->dir, $err);
  }
  $self->_watch_obj->{$self->dir} = $watch;
  return $watch;
}

sub watch {
  my $self = shift;
  $self->_watch_setup;
  while (1) {
    my $received = $self->_notifier->poll(); #this blocks
    _log("Event count $received");
  }
  return;
}

sub _cancel_watch {
  my $self = shift;
  foreach my $key (keys %{$self->_watch_obj}) {
    my $w = $self->_watch_obj->{$key};
    if ($w && (ref $w eq q[Linux::Inotify2::Watch])) {
      _log('canceling watch for ' . $w->name);
      $w->cancel;
      delete $self->_watch_obj->{$key};
    }
  }
  return;
}

sub _log {
  my $m = shift;
  if ($m) {
    warn "$m\n";
  }
  return;
}

sub DEMOLISH {
  my $self = shift;
  $self->_cancel_watch();
  return;
}

no Moose;

1;
__END__

=head1 NAME

npg_tracking::monitor::status

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 watch

 Starts and perpetuates the watch.
 This method never returns. The caller should
 use cancel_watch method to cancel all current
 watches andrelease system resources associated
 with them.

=head2 DEMOLISH

 Custom descructor for the object, calls cancel_watch

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English

=item Linux::Inotify2

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Limited

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
