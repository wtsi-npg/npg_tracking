package npg_tracking::monitor::status;

use Moose;
use Moose::Meta::Class;
use Carp;
use English qw(-no_match_vars);
use Readonly;
use Linux::Inotify2;
use Errno qw(EINTR EIO :POSIX);
use File::Basename;
use Try::Tiny;
use File::Spec::Functions;

use npg_tracking::util::types;
use npg_tracking::illumina::run::folder;
use npg_tracking::illumina::run::short_info;
use npg_tracking::status;
use npg_tracking::Schema;

our $VERSION = '0';

Readonly::Scalar my $STATUS_DIR_KEY   => q[status_dir];
Readonly::Scalar my $RUNFOLDER_KEY    => q[top_level];
Readonly::Scalar my $STATUS_DIR_NAME  => q[status];

has 'transit' =>  (isa             => 'NpgTrackingDirectory',
                   is              => 'ro',
                   required        => 1,
);

has 'destination' =>  (isa             => 'Maybe[NpgTrackingDirectory]',
                       is              => 'ro',
                       required        => 0,
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
  # watch is blocking by default
  #$inotify->blocking(); #remove blocking
  return $inotify;
}

has '_schema' => ( reader     => 'schema',
                  is         => 'ro',
                  isa        => 'npg_tracking::Schema',
                  lazy_build => 1,
);

sub _build__schema {
  return npg_tracking::Schema->connect();
}

has '_watch_obj'  =>  (isa             => 'HashRef',
                       is              => 'ro',
                       required        => 0,
                       init_arg        => undef,
                       default         => sub { {} },
);

has '_stock_runfolders'   =>  (isa             => 'ArrayRef',
                               is              => 'ro',
                               required        => 0,
                               lazy_build      => 1,
);
sub _build__stock_runfolders {
  my $self = shift;

  my @top_level = $self->destination ?
                 ($self->destination, $self->transit) :
                 ($self->transit)  ;

  my @folders = ();
  foreach my $top (@top_level) {
    opendir(my $dh, $top) || croak "Can't opendir $top: $ERRNO";
    while(readdir $dh) {
      if ($_ eq q[.] || $_ eq q[..]) {
        next;
      }
      my $dir = "$top/$_";
      if ( -d $dir ) {
        push @folders, $dir;
      }
    }
    closedir $dh;
  }
  return \@folders;
}

sub _error {
  my ($self, $path, $error) = @_;
  $self->cancel_watch();
  my $m;
  ##no critic (ControlStructures::ProhibitCascadingIfElse)
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
  ##no critic (policy ControlStructures::ProhibitUnreachableCode)
  return;
}

sub _log {
  my $m = shift;
  if ($m) {
    warn "$m\n";
  }
  return;
}

sub _path_is_latest_summary {
  my $path = shift;
  if (!$path) {
    croak 'Path should be defined';
  }
  ##no critic (TestingAndDebugging::ProhibitNoWarnings)
  no warnings qw(once);
  my $ls = $npg_tracking::illumina::run::folder::SUMMARY_LINK;
  # Not checking here that the path is a soft link
  return $path =~ /\/$ls\z/smx;
}

sub _runfolder_latest_summary_link {
  my $path = shift;
  if (!$path) {
    croak 'Path should be defined';
  }
  ##no critic (TestingAndDebugging::ProhibitNoWarnings)
  no warnings qw(once);
  my $ls = catfile($path,  $npg_tracking::illumina::run::folder::SUMMARY_LINK);
  return -l $ls ? $ls : undef;
}

sub _runfolder_prop {
  my ($self, $runfolder_path, $runfolder_prop_name) = @_;

  if (!$runfolder_path) {
    croak 'Runfolder path should be defined';
  }
  if (!$runfolder_prop_name) {
    croak 'Required runfolder property name should be defined';
  }

  $runfolder_path =~ s/\/$//smx;
  my ($runfolder, $top_path) = fileparse $runfolder_path;
  if (!$runfolder) {
    croak "Failed to get runfolder name from $runfolder_path";
  }

  my $prop_name = $runfolder_prop_name eq $STATUS_DIR_KEY ?
                    'analysis_path' : $runfolder_prop_name;

  my $prop;
  try {
    $prop = Moose::Meta::Class->create_anon_class(
      roles => [qw/npg_tracking::illumina::run::folder
                   npg_tracking::illumina::run::short_info/]
    )->new_object(
      {runfolder_path => $runfolder_path, run_folder => $runfolder}
    )->$prop_name;
  } catch {
    croak "Failed to get $prop_name from $runfolder_path: $_";
  };

  if (!$prop) {
    croak "Failed to get $prop_name from $runfolder_path: undefined value returned";
  }

  if ($runfolder_prop_name ne $STATUS_DIR_KEY) {
    return $prop;
  }

  my $path = catdir($prop, $STATUS_DIR_NAME);
  if (!-d $path) {
    croak "Status directory $path does not exist";
  }
  return $path;
}

sub _read_status {
  my ($self, $path, $runfolder_path) = @_;

  if (!$path) {
    croak 'Path should be defined';
  }

  my $status;
  try {
    $status = npg_tracking::status->from_file($path);
  } catch {
    croak "Error instantiating object from $path: $_";
  };

  my $id_run = $self->_runfolder_prop($runfolder_path, 'id_run');
  if ($id_run != $status->id_run) {
    croak sprintf 'id-run %i from runfolder %s does not match id_run %i from json file %s',
                      $id_run, $runfolder_path, $status->id_run, $path;
  }

  return $status;
}

sub _update_status4files {
  my ($self, $files, $runfolder_path) = @_;

  if (!defined $files) {
    croak 'Expect a file array as the first argument';
  }
  if (!defined $runfolder_path) {
    croak 'Expect runfolder path as the second argument';
  }

  foreach my $file ( @{$files} ) {
    try {
      _log("\nReading status from $file");
      my $status = $self->_read_status($file, $runfolder_path);
      _log('Saving to database [' . $status->to_string . "]\n");
      $self-> _update_status($status);
    } catch {
      _log("Error saving status: $_\n");
    }
  }
  return;
}

sub _update_status {
  my ($self, $status) = @_;

  my $run_row = $self->schema->resultset('Run')->find($status->id_run);
  if (!$run_row) {
    croak sprintf 'Run id %i does not exist', $status->id_run;
  }

  my $date = $status->timestamp_obj;
  my $user = undef;

  if ( !@{$status->lanes} ) {
    $run_row->update_run_status($status->status, $user, $date);
  } else {
    my %run_lanes = map { $_->position => $_} $run_row->run_lanes->all();
    foreach my $pos (@{$status->lanes}) {
      if (!exists $run_lanes{$pos}) {
        croak sprintf 'Lane %i does not exist in run %i', $pos, $status->id_run;
      }
    }
    foreach my $pos (sort { $a <=> $b} @{$status->lanes}) {
      $run_lanes{$pos}->update_status($status->status, $user, $date);
    }
  }

  return;
}

sub _stock_status_check {
  my $self = shift;

  my $m = 'Processing backlog';
  _log('Started ' . lc $m);
  foreach my $runfolder_path (@{$self->_stock_runfolders}) {
    if (!_runfolder_latest_summary_link($runfolder_path)) {
      _log("$m: runfolder $runfolder_path does not have the latest summary link, skipping.");
      next;
    }
    _log("$m: looking for status directory in $runfolder_path");
    try {
      my $status_path = $self->_runfolder_prop($runfolder_path, $STATUS_DIR_KEY);
      _log("Looking for status files in $status_path");
      my @files = glob qq("${status_path}/*.json");
      if (@files) {
        $self->_update_status4files(\@files, $runfolder_path);
      } else {
        _log("$m: no status files found in $status_path");
      }
    } catch {
      _log("$m: failed to get status path from $runfolder_path: $_");
    }
  }
  _log('Finished ' . lc $m);
  return;
}

sub _runfolder_watch_cancel {
  my ($self, $dir) = @_;

  _log("runforder $dir watch cancel called");
  my $name = basename($dir);
  if (exists $self->_watch_obj->{$name}) {
    foreach my $key (keys %{$self->_watch_obj->{$name}}) {
      my $w = $self->_watch_obj->{$name}->{$key};
      if ($w) {
        $w->cancel;
      }
    }
    delete $self->_watch_obj->{$name};
  }
  return;
}

sub _run_status_watch_cancel {
  my ($self, $path) = @_;

  foreach my $runfolder_name (keys %{$self->_watch_obj}) {
    my $test_watch = $self->_watch_obj->{$runfolder_name}->{$STATUS_DIR_KEY};
    if ($test_watch && $test_watch->name eq $path) {
      $test_watch->cancel;
      delete $self->_watch_obj->{$runfolder_name}->{$STATUS_DIR_KEY};
      last;
    }
  }
  return;
}

sub _transit_watch_setup {
  my $self = shift;

  my $watch = $self->_notifier->watch($self->transit,
    IN_ISDIR | IN_UNMOUNT | IN_IGNORED | IN_MOVED_TO | IN_DELETE, sub {
      my $e = shift;
      my $name = $e->fullname;
      if ($e->IN_IGNORED) {
        $self->cancel_watch();
        croak "Events for $name have been lost";
      }
      if ($e->IN_UNMOUNT) {
        $self->cancel_watch();
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
    $self->_error($self->transit, $err);
  } else {
    $self->_watch_obj->{$self->transit} = $watch;
  }
  return;
}

sub _stock_watch_setup {
  my $self = shift;
  foreach my $dir (@{$self->_stock_runfolders}) {
    $self->_runfolder_watch_setup($dir);
  }
  return;
}

sub _runfolder_watch_setup {
  my ($self, $dir) = @_;
  _log("runforder $dir watch setup called");

  my $runfolder_name = basename $dir;
  if (exists $self->_watch_obj->{$runfolder_name}->{$RUNFOLDER_KEY}) {
    _log("Already watching $dir");
    return;
  }

  my $watch = $self->_notifier->watch($dir,
    IN_DONT_FOLLOW | IN_IGNORED | IN_DELETE | IN_CREATE, sub {
      my $e = shift;
      my $name = $e->fullname;
      if ($e->IN_IGNORED) {
        $self->_runfolder_watch_cancel($name);
      } elsif ($e->IN_DELETE) {
        if (_path_is_latest_summary($name)) {
          $self->_run_status_watch_cancel($name);
        }
      } elsif ($e->IN_CREATE) {
        if (_path_is_latest_summary($name)) {
          $self->_run_status_watch_setup($name);
        }
      }
  });

  if (!$watch) {
    my $err = $ERRNO;
    $self->_error($dir, $err);
  } else {
    $self->_watch_obj->{$runfolder_name}->{$RUNFOLDER_KEY} = $watch;
  }

  my $sl = _runfolder_latest_summary_link($dir);
  if ($sl) {
    $self->_run_status_watch_setup($sl);
  }

  return;
}

sub _run_status_watch_setup {
  my ($self, $summary_link) = @_;

  if (!$summary_link) {
    croak 'Summary link path undefined';
  }
  _log("Setting watch for $summary_link");

  my $runfolder_name = basename $summary_link;
  my ($filename, $runfolder_path) = fileparse $summary_link;

  if (exists $self->_watch_obj->{$runfolder_name}->{$RUNFOLDER_KEY}) {
    _log("Already watching status directory in $runfolder_name");
    return;
  }

  my $status_dir;
  try {
    $status_dir = $self->_runfolder_prop($runfolder_path, $STATUS_DIR_KEY);
  } catch {
    _log("Failed to set watch for $summary_link: $_");
    return;
  };

  my $watch = $self->_notifier->watch( $status_dir,
    IN_IGNORED | IN_CLOSE_WRITE, sub {
      my $e = shift;
      my $name = $e->fullname;
      if ($e->IN_IGNORED) {
        $self->_run_status_watch_cancel($name);
      } elsif ($e->IN_CLOSE_WRITE) {
        $self->_update_status4files([$name], $runfolder_path);
      }
  });

  if (!$watch) {
    my $err = $ERRNO;
    $self->_error($status_dir, $err);
  } else {
    $self->_watch_obj->{$runfolder_name}->{$STATUS_DIR_KEY} = $watch;
  }
  return;
}

sub cancel_watch {
  my $self = shift;

  #stop registering new runfolders events;
  my $transit_watch = $self->_watch_obj->{$self->transit};
  if ($transit_watch && ref $transit_watch eq q[Linux::Inotify2::Watch]) {
    _log('canceling watch for ' . $transit_watch->name);
    $transit_watch->cancel;
  }
  delete $self->_watch_obj->{$self->transit};

  foreach my $runfolder (keys %{$self->_watch_obj}) {
    foreach my $key (keys %{$self->_watch_obj->{$runfolder}}) {
      my $w = $self->_watch_obj->{$runfolder}->{$key};
      if ($w && (ref $w eq q[Linux::Inotify2::Watch])) {
        _log('canceling watch for ' . $w->name);
        $w->cancel;
        delete $self->_watch_obj->{$runfolder}->{$key};
      }
    }
    delete $self->_watch_obj->{$runfolder};
  }

  return;
}

sub watch {
  my $self = shift;

  $self->_transit_watch_setup;
  $self->_stock_watch_setup;

  my $child = fork;
  if (!defined $child) {
    croak "Fork failed: $ERRNO";
  }

  if ($child) {
    while (1) {
      my $received = $self->_notifier->poll(); # This call blocks,
                                               # unless non-blocking mode is
                                               # set on $self->_notifier.
      _log("Event count $received");
    }
  } else {
    $self->_stock_status_check;
    exit 0; # Might close parent filehandles on some Unix systems,
            # but not on Linux.
  }
  wait or croak "Child error: $CHILD_ERROR >> 8";

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
 watches and release system resources associated
 with them.

=head2 cancel_watch

 Stops watch on all objects.

=head2 EBADF (namespace pollution from Errno module)

=head2 ENOMEM (namespace pollution from Errno module)

=head2 ENOSPC (namespace pollution from Errno module)

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Moose::Meta::Class

=item Carp

=item English

=item Readonly

=item Linux::Inotify2

=item File::Basename

=item Errno

=item Try::Tiny

=item File::Spec::Functions

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
