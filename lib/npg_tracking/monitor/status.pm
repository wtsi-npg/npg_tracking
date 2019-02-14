package npg_tracking::monitor::status;

use Moose;
use Moose::Meta::Class;
use Carp;
use English qw(-no_match_vars);
use Readonly;
use Errno qw(EINTR EIO :POSIX);
use File::Basename;
use Try::Tiny;
use File::Spec::Functions;
use Linux::Inotify2;
use Sys::Filesystem;
use Sys::Filesystem::MountPoint qw/path_to_mount_point/;
use File::stat;

use npg_tracking::util::types;
use npg_tracking::illumina::run::folder;
use npg_tracking::illumina::run::short_info;
use npg_tracking::status;
use npg_tracking::Schema;

our $VERSION = '0';

Readonly::Scalar my $STATUS_DIR_KEY   => q[status_dir];
Readonly::Scalar my $RUNFOLDER_KEY    => q[top_level];
Readonly::Scalar my $STATUS_DIR_NAME  => q[status];
Readonly::Scalar my $POLLING_INTERVAL => 60;

has 'transit'     =>  (isa             => 'NpgTrackingDirectory',
                       is              => 'ro',
                       required        => 1,
);

has 'destination' =>  (isa             => 'Maybe[NpgTrackingDirectory]',
                       is              => 'ro',
                       required        => 0,
);

has 'blocking'    =>  (isa             => 'Bool',
                       is              => 'ro',
                       required        => 0,
                       default         => 1,
);

has 'verbose'     =>  (isa             => 'Bool',
                       is              => 'ro',
                       required        => 0,
                       default         => 1,
);

has 'enable_inotify' => (isa           => 'Bool',
                         is            => 'ro',
                         required      => 0,
                         default       => 1,
);

has 'polling_interval' => (isa         => 'Int',
                           is          => 'ro',
                           required    => 0,
                           default     => $POLLING_INTERVAL,
);

has '_notifier'   =>   (isa             => 'Linux::Inotify2',
                        is              => 'ro',
                        required        => 0,
                        init_arg        => undef,
                        lazy_build      => 1,
);
sub _build__notifier {
  my $self = shift;
  my $inotify = Linux::Inotify2->new()
    or croak "unable to create new inotify object: $ERRNO";
  # Watch is blocking by default
  if (!$self->blocking) {
    $inotify->blocking(); # Remove blocking
  }
  return $inotify;
}

has '_latest_summary_name' => (
                       isa             => 'Str',
                       is              => 'ro',
                       required        => 0,
                       lazy_build      => 1,
);
sub _build__latest_summary_name {
  ##no critic (TestingAndDebugging::ProhibitNoWarnings)
  no warnings qw(once);
  return $npg_tracking::illumina::run::folder::SUMMARY_LINK;
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
  return $self->_list_stock_runfolders();
}

has '_seen_cache'        =>  (isa             => 'HashRef',
                              traits          => ['Hash'],
                              is              => 'bare',
                              default         => sub { {} },
                              handles   => {
                                _cache_file    => 'set',
                                _file_in_cache => 'get',
                              },
);

sub _list_stock_runfolders {
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
  my ($self, $m) = @_;
  if ($m && $self->verbose) {
    warn "$m\n";
  }
  return;
}

sub _path_is_latest_summary {
  my ($self, $path) = @_;
  if (!$path) {
    croak 'Path should be defined';
  }
  my $ls = $self->_latest_summary_name;
  # Not checking here that the path is a soft link
  # because the link might have been deleted by now
  return $path =~ /\/$ls\z/smx;
}

sub _runfolder_latest_summary_link {
  my ($self, $path) = @_;
  if (!$path) {
    croak 'Path should be defined';
  }
  my $ls = catfile($path,  $self->_latest_summary_name);
  return -l $ls ? $ls : undef;
}

sub _runfolder_name_and_path {
  my $runfolder_path = shift;
  $runfolder_path =~ s/\/$//smx;
  my ($runfolder_name, $top_path) = fileparse $runfolder_path;
  if (!$runfolder_name) {
    croak "Failed to get runfolder name from $runfolder_path";
  }
  return ($runfolder_name, $runfolder_path);
}

sub _runfolder_name_and_path_from_summary_link {
  my $summary_link = shift;
  my ($filename, $path) = fileparse $summary_link;
  return _runfolder_name_and_path($path);
}

sub _runfolder_prop {
  my ($self, $path, $runfolder_prop_name) = @_;

  if (!$path) {
    croak 'Runfolder path should be defined';
  }
  if (!$runfolder_prop_name) {
    croak 'Required runfolder property name should be defined';
  }

  my ($runfolder, $runfolder_path) = _runfolder_name_and_path($path);

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

  my $spath = catdir($prop, $STATUS_DIR_NAME);
  if (!-d $spath) {
    croak "Status directory $path does not exist";
  }
  return $spath;
}

sub _update_status4files {
  my ($self, $files, $runfolder_path) = @_;

  if (!defined $files) {
    croak 'Expect a file array as the first argument';
  }
  if (!defined $runfolder_path) {
    croak 'Expect runfolder path as the second argument';
  }

  my $num_saved = 0;

  foreach my $file ( @{$files} ) {
    my $modify_time = stat($file)->mtime;
    my $cached_time = $self->_file_in_cache($file);
    #####
    # If the pipeline is run repeatedly using the same analysis
    # directory, status files might get overwritten. We should
    # save the latest status even if this status had been saved
    # in the past.
    next if (defined $cached_time && ($cached_time eq $modify_time));
    try {
      $self->_log("\nReading status from $file");
      my $status = $self->_read_status($file, $runfolder_path);
      $self->_update_status($status);
      $self->_cache_file($file, $modify_time);
      $num_saved++;
    } catch {
      $self->_log("Error saving status: $_\n");
    }
  }
  return $num_saved;
}

sub _find_path {
  my ($self, $path) = @_;
  if ($self->destination && !-e $path) {
    my $transit = $self->transit;
    my $destination = $self->destination;
    if ($path =~ /$transit/smx) {
      $path =~ s/^$transit/$destination/smx;
    } else {
      $path =~ s/^$destination/$transit/smx;
    }
    if (-e $path) {
      return $path;
    }
  }
  return;
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
    my $error = $_;
    my $new_path = $self->_find_path($path);
    if ($new_path) {
      try {
        $status = npg_tracking::status->from_file($new_path);
      } catch {
        croak "Error instantiating object from $new_path: $error";
      };
    } else {
      croak "Error instantiating object from $path: $error";
    }
  };

  my $id_run = $self->_runfolder_prop($runfolder_path, 'id_run');
  if ($id_run != $status->id_run) {
    croak sprintf 'id-run %i from runfolder %s does not match id_run %i from json file %s',
                      $id_run, $runfolder_path, $status->id_run, $path;
  }

  return $status;
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
    if ($run_row->update_run_status($status->status, $user, $date)) {
      $self->_log('Run status saved');
    } else {
      $self->_log('Run status not saved');
    }
  } else {
    my %run_lanes = map { $_->position => $_} $run_row->run_lanes->all();
    foreach my $pos (@{$status->lanes}) {
      if (!exists $run_lanes{$pos}) {
        croak sprintf 'Lane %i does not exist in run %i', $pos, $status->id_run;
      }
    }
    foreach my $pos (sort { $a <=> $b} @{$status->lanes}) {
      if ($run_lanes{$pos}->update_status($status->status, $user, $date)) {
        $self->_log('Lane status saved');
      } else {
        $self->_log('Lane status not saved');
      }
    }
  }

  return;
}

sub _stock_status_check {
  my $self = shift;

  my $m = 'Processing backlog';
  $self->_log('Started ' . lc $m);
  foreach my $runfolder_path (@{$self->_list_stock_runfolders}) {
    if (!-e $runfolder_path) { # runfolder could have been moved or deleted
      $self->_log("Runfolder $runfolder_path does not exist in this location");
      next;
    }
    if (!$self->_runfolder_latest_summary_link($runfolder_path)) {
      $self->_log("$m: runfolder $runfolder_path does not have the latest summary link, skipping.");
      next;
    }
    $self->_log("$m: looking for status directory in $runfolder_path");
    $self->_runfolder_status_check($runfolder_path);
  }
  $self->_log('Finished ' . lc $m);
  return;
}

sub _runfolder_status_check {
  my ($self, $runfolder_path) = @_;

  my $m = 'Processing backlog';
  try {
    my $status_path = $self->_runfolder_prop($runfolder_path, $STATUS_DIR_KEY);
    $self->_log("Looking for status files in $status_path");
    my @files = glob "${status_path}/*.json";
    if (@files) {
      $self->_update_status4files(\@files, $runfolder_path);
    } else {
      $self->_log("$m: no status files found in $status_path");
    }
  } catch {
    $self->_log("$m: failed to get existing status files from $runfolder_path: $_");
  };
  return;
}

sub _runfolder_watch_cancel {
  my ($self, $dir) = @_;

  $self->_log("Runfolder $dir watch cancel called");
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
        $self->_log("$name deleted");
        $self->_runfolder_watch_cancel($name);
      } elsif ($e->IN_MOVED_TO) {
        $self->_log("$name moved to the watched directory");
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
  $self->_log("Runfolder $dir watch setup called");

  my $runfolder_name = basename $dir;
  if (exists $self->_watch_obj->{$runfolder_name}->{$RUNFOLDER_KEY}) {
    $self->_log("Already watching $dir");
    return;
  }

  my $watch = $self->_notifier->watch($dir,
    IN_DONT_FOLLOW | IN_IGNORED | IN_DELETE | IN_CREATE, sub {
      my $e = shift;
      my $name = $e->fullname;
      if ($e->IN_IGNORED) {
        $self->_runfolder_watch_cancel($name);
      } elsif ($e->IN_CREATE) {
        if ($self->_path_is_latest_summary($name)) {
          $self->_run_status_watch_setup($name, 1);
          $self->_runfolder_status_check($dir);
        }
      }
  });

  if (!$watch) {
    my $err = $ERRNO;
    $self->_error($dir, $err);
  } else {
    $self->_watch_obj->{$runfolder_name}->{$RUNFOLDER_KEY} = $watch;
  }

  my $sl = $self->_runfolder_latest_summary_link($dir);
  if ($sl) {
    $self->_run_status_watch_setup($sl);
  }

  return;
}

sub _run_status_watch_setup {
  my ($self, $summary_link, $cancel_existing) = @_;

  if (!$summary_link) {
    croak 'Summary link path undefined';
  }
  $self->_log("Setting watch for $summary_link");

  my ($runfolder_name, $runfolder_path) =
    _runfolder_name_and_path_from_summary_link($summary_link);

  my $status_dir;
  my $error = q[];
  try {
    $status_dir = $self->_runfolder_prop($runfolder_path, $STATUS_DIR_KEY);
  } catch {
    $error = $_;
  };
  if (!$status_dir) {
    # Unfortunatelly, return from the catch clause above does not work
    $self->_log("Failed to set watch for $summary_link: $error");
    return;
  }

  if (exists $self->_watch_obj->{$runfolder_name}->{$STATUS_DIR_KEY}) {
    if ($cancel_existing) {
      $self->_cancel($self->_watch_obj->{$runfolder_name}->{$STATUS_DIR_KEY});
      delete $self->_watch_obj->{$runfolder_name}->{$STATUS_DIR_KEY};
    } else {
      $self->_log("Already watching status directory in $runfolder_name");
      return;
    }
  }

  my $watch = $self->_notifier->watch( $status_dir,
    IN_CLOSE_WRITE, sub {
      my $e = shift;
      if ($e->IN_CLOSE_WRITE) {
        $self->_update_status4files([$e->fullname], $runfolder_path);
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

sub _cancel {
  my ($self, $watch) = @_;
  if ($watch && ref $watch eq q[Linux::Inotify2::Watch]) {
    $self->_log('Canceling watch for ' . $watch->name);
    $watch->cancel;
  }
  return;
}

sub cancel_watch {
  my $self = shift;
  $self->_cancel($self->_watch_obj->{$self->transit});
  delete $self->_watch_obj->{$self->transit};

  foreach my $runfolder (keys %{$self->_watch_obj}) {
    foreach my $key (keys %{$self->_watch_obj->{$runfolder}}) {
      $self->_cancel($self->_watch_obj->{$runfolder}->{$key});
      delete $self->_watch_obj->{$runfolder}->{$key};
    }
    delete $self->_watch_obj->{$runfolder};
  }
  return;
}

sub watch {
  my $self = shift;

  if ($self->enable_inotify) {
    $self->_transit_watch_setup;
    $self->_stock_watch_setup;
  }
  $self->_stock_status_check;

  while (1) {
    if ($self->enable_inotify) {
      # This call blocks unless non-blocking mode is set.
      my $received = $self->_notifier->poll();
    } else {
      sleep $self->polling_interval;
      $self->_stock_status_check;
    }
  }
  return;
}

sub staging_fs_type {
  my ($self, $path) = @_;

  $path and -e $path or croak 'Existing path required';

  my $mount_point = path_to_mount_point($path);
  if (!defined $mount_point) {
    ##no critic (Variables::ProhibitPackageVars)
    croak "Failed to detect mount point for $path: " .
      $Sys::Filesystem::MountPoint::errstr;
  }

  return Sys::Filesystem->new()->type($mount_point);
}

sub DEMOLISH {
  my $self = shift;
  if ($self->enable_inotify) {
    $self->cancel_watch();
  }
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

=head2 transit

One of the directories to watch. An initial location of run
folders, a required attribute.

=head2 destination

One of the directories to watch. An optional attribute. A location
run folders are normally moved to from the transit location.

=head2 blocking

Boolean flag setting blocking mode for inotify. True by default.

=head2 verbose

Boolean flag, defaults to true.

=head2 enable_inotify

A boolean flag enabling inotify watch over relevant directories.
True by default.

=head2 polling_interval

If inotify is not enabled, a poll for new statuses is performed
periodically. This attribute sets time in seconds between the
polling attempts. If not set, a default value of 60 is used.

=head2 watch

Starts and perpetuates the watch. This method never returns.
The caller should use cancel_watch method to cancel all current
watches and release system resources associated with them.

=head2 cancel_watch

If inotify is enabled, stops watch on all objects and remove
watch objects.

=head2 staging_fs_type

Returns file system type for the argument staging path.

  npg_tracking::monitor::status->staging_fs_type($staging_path);
  $obj->staging_fs_type($staging_path);

=head2 DEMOLISH

A Moose hook for object destruction; calls cancel_watch().

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

=item Sys::Filesystem

=item Sys::Filesystem::MountPoint

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 Genome Research Limited

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
