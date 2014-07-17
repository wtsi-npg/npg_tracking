package npg_tracking::monitor::status;

use Moose;
use Carp;
use English qw(-no_match_vars);
use Linux::Inotify2;

our $VERSION = '0';

has 'dir'        =>   (isa             => 'Str',
                       is              => 'ro',
                       required        => 1,
                      );

has 'link'       =>   (isa             => 'Str',
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

has '_watch_obj'  =>  (isa             => 'ArrayRef',
                       is              => 'ro',
                       required        => 0,
                       init_arg        => undef,
                       default         => sub { [] },
                      );

sub _setup {
  my $self = shift;

  push @{$self->_watch_obj},
  $self->_notifier->watch($self->link, IN_DONT_FOLLOW | IN_IGNORED, sub {
    my $e = shift;
    _log('callback invoked');
    my $name = $e->fullname;
    if ( $e->IN_IGNORED ) {
      _log("events for $name have been lost");
    }
    $e->w->cancel;
  });

  push @{$self->_watch_obj},
  $self->_notifier->watch($self->dir, IN_CLOSE_WRITE | IN_IGNORED, sub {
    my $e = shift;
    _log('callback invoked');
    my $name = $e->fullname;
    if ( $e->IN_CLOSE_WRITE ) {
      _log("$name was written to");
    } elsif ($e->IN_IGNORED) {
      _log("events for $name have been lost");
      $e->w->cancel;
    }
  });

  return;
}

sub watch {
  my $self = shift;
  $self->_setup;
  while (1) {
    my $received = $self->_notifier->poll(); #this blocks
    _log("Event count $received");
  }
  return;
}

sub cancel_watch {
  my $self = shift;
  foreach my $w (@{$self->_watch_obj}) {
    if ($w) {
      _log('canceling watch for ' . $w->name);
      $w->cancel;
    }
  }
  return;
}

sub _log {
  my $m = shift;
  if ($m) {
    print "$m\n" or carp "Failed to log message $m";
  }
  return;
}

sub DEMOLISH {
  my $self = shift;
  $self->cancel_watch();
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

=head2 cancel_watch

 Cancels all known watches

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
