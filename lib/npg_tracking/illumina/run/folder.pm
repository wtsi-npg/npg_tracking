#############
# Created By: ajb
# Created On: 2009-10-01

package npg_tracking::illumina::run::folder;

use Moose::Role;
use Moose::Meta::Class;
use File::Spec::Functions qw(splitdir catfile catdir);
use Carp qw(carp cluck croak confess);
use Cwd qw/getcwd abs_path/;
use Try::Tiny;
use Readonly;

use npg_tracking::Schema;
use npg_tracking::glossary::lane;

our $VERSION = '0';

with 'npg_tracking::illumina::run::folder::location';

##no critic (Subroutines::ProhibitUnusedPrivateSubroutines)

Readonly::Scalar my $DATA_DIR       => q{Data};
Readonly::Scalar my $QC_DIR         => q{qc};
Readonly::Scalar my $BASECALL_DIR   => q{BaseCalls};
Readonly::Scalar my $ARCHIVE_DIR    => q{archive};
Readonly::Scalar my $SUMMARY_LINK   => q{Latest_Summary};
Readonly::Array  my @RECALIBRATED_DIR_MATCH  => qw( PB_cal no_cal ) ;
Readonly::Array  my @BUSTARD_DIR_MATCH       => ( q{Bustard}, $BASECALL_DIR,  q{_basecalls_} );
Readonly::Array  my @INTENSITY_DIR_MATCH     => qw( Intensities );

Readonly::Array our @ORDER_TO_ASSESS_SUBPATH_ASSIGNATION => qw(
      recalibrated_path basecall_path bustard_path intensity_path
      pb_cal_path qc_path archive_path runfolder_path
  );

Readonly::Hash my %NPG_PATH  => (
  q{analysis_path}     => 'Path to the top level custom analysis directory',
  q{reports_path}      => 'Path to the "reports" directory',
  q{intensity_path}    => 'Path to the "Intensities" directory',
  q{bustard_path}      => 'Path to the Bustard directory',
  q{basecall_path}     => 'Path to the "Basecalls" directory',
  q{recalibrated_path} => 'Path to the recalibrated qualities directory',
  q{pb_cal_path}       => 'Path to the "PB_cal" directory',
  q{archive_path}      => 'Path to the directory with data ready for archiving',
  q{qc_path}           => 'Path directory with top level QC data',
);

foreach my $path_attr ( keys %NPG_PATH ) {
  has $path_attr => (
    isa           => q{Str},
    is            => q{ro},
    lazy_build    => 1,
    writer        => q{_set_} . $path_attr,
    documentation => $NPG_PATH{$path_attr},
  );
}

has q{dif_files_path} => (
  isa           => q{Str},
  is            => q{ro},
  predicate     => q{has_dif_files_path},
  writer        => q{set_dif_files_path},
  documentation => 'Path to the dif files directory',
);
sub _set_dif_files_path { #retained for compatibility with the pipeline
  my ($self, $path) = @_;
  $self->set_dif_files_path($path);
  return;
}

has q{bam_basecall_path}  => (
  isa           => q{Str},
  is            => q{ro},
  predicate     => 'has_bam_basecall_path',
  writer        => 'set_bam_basecall_path',
  documentation => 'Path to the "BAM Basecalls" directory',
);
sub _set_bam_basecall_path { #retained for compatibility with the pipeline
  my ($self, $path) = @_;
  $self->set_bam_basecall_path($path);
  return;
}

has q{npg_tracking_schema} => (
  isa => q{Maybe[npg_tracking::Schema]},
  is => q{ro},
  lazy_build => 1,
);
sub _build_npg_tracking_schema {
  my $schema;
  try {
    $schema = npg_tracking::Schema->connect();
  } catch {
    warn qq{WARNING: Unable to connect to NPG tracking DB for faster globs.\n};
  };
  return $schema;
}

has q{subpath} => (
  isa       => q{Str},
  is        => q{ro},
  predicate => q{has_subpath},
  writer    => q{_set_subpath},
);

sub _given_path {
  my ($self) = @_;

  if ($self->has_subpath()) {
    return $self->subpath();
  }

  my $subpath = q{};
  foreach my $path_method (@ORDER_TO_ASSESS_SUBPATH_ASSIGNATION) {
    my $has_path_method = q{has_} . $path_method;
    if ($self->$has_path_method()) {
      $subpath = $self->$path_method();
      last;
    }
  }

  $self->_set_subpath($subpath);
  return $subpath;
}

sub _build_analysis_path {
  my ($self) = @_;

  if ($self->has_bam_basecall_path) {
    return $self->bam_basecall_path;
  }
  if ($self->has_bustard_path) {
    return $self->bustard_path;
  }
  if ($self->has_archive_path) {
    return _infer_analysis_path($self->archive_path, 2);
  }

  if ($self->has_recalibrated_path || $self->recalibrated_path) {
    return _infer_analysis_path($self->recalibrated_path, 1);
  }

  return q{};
}

sub _infer_analysis_path {
  my ($path, $distance) = @_;

  my @path_components = splitdir( abs_path $path );
  if (scalar @path_components <= $distance) {
    croak qq[path $path is too short for distance $distance];
  }
  while ($distance > 0) {
    pop @path_components;
    $distance--;
  }
  return File::Spec->catdir( @path_components );
}

sub _build_intensity_path {
  my ($self) = @_;
  $self->_populate_directory_paths();
  return $self->intensity_path();
}

sub _build_bustard_path {
  my ($self) = @_;
  $self->_populate_directory_paths();
  return $self->bustard_path();
}

sub _build_basecall_path {
  my ($self) = @_;
  $self->_populate_directory_paths();
  return $self->basecall_path();
}

sub _build_recalibrated_path {
  my ($self) = @_;
  $self->_populate_directory_paths();
  return $self->recalibrated_path();
}

sub _build_pb_cal_path {
  my ($self) = @_;
  $self->_populate_directory_paths();
  return $self->pb_cal_path();
}

sub _build_reports_path {
  my ($self) = @_;
  return catdir($self->runfolder_path(), $DATA_DIR, q{reports});
}

sub _build_archive_path {
  my ($self) = @_;
  return $self->recalibrated_path() . q{/} . $ARCHIVE_DIR;
}

sub _build_qc_path {
  my ($self) = @_;
  return $self->archive_path() . q{/} . $QC_DIR;
}

sub _populate_directory_paths {
  my ($self) = @_;
  my $path = $self->has_recalibrated_path() ? $self->recalibrated_path() :
    $self->_find_recalibrated_directory_path($self->runfolder_path());
  return $self->_process_path($path);
}

sub _process_path {
  my ($self, $path) = @_;

  my @path = split m{/}xms, $path;

  my ($intensity_dir, $bustard_dir, $recalibrated_dir) = (q{},q{},q{});

  foreach my $section (@path) {

    my $populated_something = 0;
    foreach my $dir_name ( @INTENSITY_DIR_MATCH ) {
      if ( $section =~ /$dir_name/xms ) {
        $intensity_dir = $section;
        $populated_something++;
        last;
      }
    }

    if ( $populated_something ) {
      next;
    }

    foreach my $dir_name ( @BUSTARD_DIR_MATCH ) {
      if ( $section =~ /$dir_name/xms ) {
        $bustard_dir = $section;
        $populated_something++;
        last;
      }
    }
    if ( $populated_something ) {
      next;
    }

    foreach my $dir_name ( @RECALIBRATED_DIR_MATCH ) {
      if ( $section =~ /$dir_name/xms ) {
        $recalibrated_dir = $section;
        $populated_something++;
        last;
      }
    }
    if ( $populated_something ) {
      next;
    }
  }

  my $use_bustard_as_recalibrated;
  if ( $intensity_dir && $bustard_dir && ! $recalibrated_dir ) {
    if ( $self->can( q{log} ) ) {
      my $msg = $self->id_run() . q{: No recalibrated_dir worked out, I will use the bustard_path as the recalibrated path, unless you have already provided it};
      $self->log( $msg );
    }
    $use_bustard_as_recalibrated++;
  }

  if ( ! ($intensity_dir && $bustard_dir) ) {
      confess $self->id_run() . qq{: no intensity or bustard directory: $path};
  }

  my $intensity_path     = catdir($self->runfolder_path(), $DATA_DIR, $intensity_dir);
  my $bustard_path       = qq{$intensity_path/$bustard_dir};
  my $basecall_path      = qq{$intensity_path/$BASECALL_DIR};
  my $recalibrated_path = $use_bustard_as_recalibrated ?  $bustard_path
                        :                                 qq{$bustard_path/$recalibrated_dir}
                        ;

  if (!$self->has_intensity_path())    { $self->_set_intensity_path($intensity_path); };
  if (!$self->has_bustard_path())      { $self->_set_bustard_path($bustard_path); };
  if (!$self->has_basecall_path())     { $self->_set_basecall_path($basecall_path); };
  if (!$self->has_pb_cal_path())       { $self->_set_pb_cal_path($bustard_path . q{/PB_cal}); };
  if (!$self->has_recalibrated_path()) { $self->_set_recalibrated_path($recalibrated_path); };

  if ($self->can(q{verbose}) && $self->verbose()) {
    foreach my $dir (qw{intensity bustard basecall recalibrated pb_cal}) {
      my $subpath_dir = $dir . q{_path};
      carp qq{$dir : } . $self->$subpath_dir();
    }
  }

  return 1;
}

sub _find_recalibrated_directory_path {
  my ( $self, $path ) = @_;
  my $recalibrated_path;

  # have users declared any subpaths, try this
  if ($self->_given_path()) {
    $recalibrated_path = $self->_recalibrated_path( $self->_given_path() );
  }
  if ($recalibrated_path) {
    return $recalibrated_path;
  }

  # try current directory, as we may already be there
  my ($dir) = getcwd() =~ m{ ([[:word:]/.,+-]+) }xms;
  $dir ||= q{};
  $dir =~ s{\A/*private}{}xms; # some environments may cause this to be appended to the directory

  if ( $dir =~ m{/Data/}xms ) {
    $recalibrated_path = $self->_recalibrated_path( $dir );
  }

  if ($recalibrated_path) {
    return $recalibrated_path;
  }

  if (-l qq{$path/$SUMMARY_LINK}) {
     $recalibrated_path = $self->_recalibrated_path( readlink qq{$path/$SUMMARY_LINK} );
  }

  if ($recalibrated_path) {
    return $recalibrated_path;
  }

  $recalibrated_path = $self->_try_to_find_recalibrated_path_from_runfolder_path($path);

  if ( ! defined $recalibrated_path) {
    croak $self->id_run() . q[: Could not find usable recalibrated directory];
  }

  return $recalibrated_path;
}

# globs the filesystem under runfolder_path to see if it can find recalibrated directory. Croaks if it finds more than one.
sub _try_to_find_recalibrated_path_from_runfolder_path {
  my ($self, $rf_path) = @_;
  $rf_path ||= $self->runfolder_path();

  my @dirs;
  foreach my $int_dir_name ( @INTENSITY_DIR_MATCH ) {
    foreach my $bustard_dir_name ( @BUSTARD_DIR_MATCH ) {
      foreach my $recal_dir_name ( @RECALIBRATED_DIR_MATCH ) {
        my @temp_dirs = glob catdir($rf_path, $DATA_DIR, qq{*$int_dir_name*}, qq{$bustard_dir_name*}, qq{$recal_dir_name*});
        push @dirs, @temp_dirs;
      }
    }
  }

  @dirs = grep {-d $_} @dirs;

  if (scalar@dirs > 1) {
    my $dirs_string = join qq{\n}, @dirs;
    croak $self->id_run() . qq{: found multiple possible recalibrated_directories\n$dirs_string\n};
  }

  if (scalar@dirs == 1) {
    return $dirs[0];
  }

  if ( $self->can( q{log} ) ) {
    my $msg = $self->id_run() . q{: no recalibrated directories found. If I find only 1 bustard level directory, I will use that};
    $self->log( $msg );
  }

  @dirs = ();
  foreach my $int_dir_name ( @INTENSITY_DIR_MATCH ) {
    foreach my $bustard_dir_name ( @BUSTARD_DIR_MATCH ) {
      push @dirs, glob catdir($rf_path, $DATA_DIR, qq{*$int_dir_name*}, qq{$bustard_dir_name*});
    }
  }

  if (scalar@dirs > 1) {
    my $dirs_string = join qq{\n}, @dirs;
    croak $self->id_run() . qq{: found multiple possible bustard level directories\n$dirs_string\n};
  }

  if (scalar@dirs == 1) {
    return $dirs[0];
  }

  return;
}

sub _recalibrated_path {
  my ($self, $dir) = @_;
  my $rf_path = $self->runfolder_path();

  if ($dir !~ /\A\Q$rf_path\E/xms) {
    $dir = $rf_path . q{/} . $dir;
  }
  my @subpath = splitdir( $dir );

  # proceed through the path (from the end) and look for a directory which matches the $RECALIBRATED_DIR_MATCH string
  while (@subpath) {
    my $path = catdir(@subpath);
    if ( -d $path # path of all remaining parts of the directory
                                                                 ) {

      foreach my $dir_name ( @RECALIBRATED_DIR_MATCH ) {
        if ( $path =~ m{/$dir_name[^/]*\z}xms ) {
          return $path
        }
      }
    }

    pop @subpath;
  }

  if ($self->can(q{verbose}) && $self->verbose()) {
    carp $dir. q{ does not appear to contain a recalibrated directory};
  }
  return;
}

# goes through all given paths (or populated paths) and attempts to find the runfolder_path from each in turn,
# selecting the first which has directories which should be present in a runfolder
sub get_path_from_given_path {
  my ($self) = @_;

  my @subpaths = reverse @ORDER_TO_ASSESS_SUBPATH_ASSIGNATION;
  unshift @subpaths, q{subpath};

  foreach my $subpath (@subpaths) {
    # proceed through the path (from the end) and look for a directory containing Config and either Data or Images directories
    my $has_method = q{has_} . $subpath;
    next if (!$self->$has_method());
    my @subpath = splitdir( $self->$subpath() );
    while (@subpath) {
      my $path = catdir(@subpath);

      if (
          -d $path # path of all remaining parts of _given_path (subpath)
            and
          -d catdir($path, q{Config}) # does this directory have a Config Directory
            and
          (
            -d catdir($path, $DATA_DIR) # a runfolder is likely to have a Data directory
              or
            -d catdir($path, q{Images}) # but if it is not a RTA run, it might have an Images directory if analysis has not been performed
          )
         ) {
           return $path;
         }
      pop @subpath;
    }
  }

  confess q{nothing looks like a run_folder in any given subpath};
}

sub lane_archive_path {
  my ($self, $position) = @_;
  my $lane =  Moose::Meta::Class->create_anon_class(
                roles => [qw/npg_tracking::glossary::lane/]
              )->new_object({position => $position});
  return catdir($self->archive_path, $lane->lane_archive);
}

sub lane_qc_path {
  my ($self, $position) = @_;
  return catdir($self->lane_archive_path($position), $QC_DIR);
}

sub lane_archive_paths {
  my $self = shift;

  my @dirs = ();
  my $archive_dir = $self->archive_path;
  opendir(my $dh, $archive_dir) || croak "Can't opendir $archive_dir";
  my @lanes = grep { /^lane\d$/smx && -d "$archive_dir/$_" } readdir $dh;
  closedir $dh;
  foreach my $lane_dir (@lanes) {
    my $dir = catdir($archive_dir, $lane_dir);
    push @dirs, $dir;
  }
  return \@dirs;
}

sub lane_qc_paths {
  my $self = shift;

  my @dirs = ();
  foreach my $path (@{$self->lane_archive_paths}) {
    my $dir = catdir($path, $QC_DIR);
    if (-d $dir) {
      push @dirs, $dir;
    }
  }
  return \@dirs;
}


1;
__END__

=head1 NAME

npg_tracking::illumina::run::folder

=head1 SYNOPSIS

  package MyPackage;
  use Moose;
  with qw{npg_tracking::illumina::run::short_info
          npg_tracking::illumina::run::folder};

  my $oPackage = MyPackage->new({
    path => q{/string/to/a/run_folder},
  });

  my $oPackage = MyPackage->new({
    path          => q{/string/to/a/run_folder},
    analysis_path => q{/recalibrated/directory/below/run_folder},
  });

=head1 DESCRIPTION

This package needs to have something provide the short_reference method, either declared in your class,
or because you have previously declared with npg_tracking::illumina::run::short_info, which is the preferred
option. If you declare short_reference manually, then it must return a string where the last digits are
the id_run.

Failure to have provided a short_reference method WILL cause a run-time error if your class needs to obtain
any paths where a path or subpath was not given in object construction (i.e. it wants to try to use id_run
to glob for it).

First, using this role will allow you to add a subpath to your constructor. This must be a directory
below the run_folder directory, but expressing the full path.

In addition to this, you can add an analysis_path, which is the path to the recalibrated directory,
which will be used to construct other paths from

=head1 SUBROUTINES/METHODS

=head2 get_path_from_given_path
Goes through all given paths (or populated paths) and attempts to find the runfolder_path from each in turn,
selecting the first which has directories which should be present in a runfolder.

=head2 path - can be given in object constructor, or worked out from subpath or short_reference

  my $sPath = $oPackage->path();

=head2 analysis_path

=head2 intensity_path - ro accessor to the intensity level directory subpath

=head2 bustard_path - ro accessor to the Bustard level directory subpath

=head2 basecall_path - ro accessor to the BaseCalls level directory subpath

=head2 recalibrated_path - ro accessor to the recalibrated level directory subpath

=head2 archive_path - ro accessor to the archive level directory subpath

=head2 lane_archive_path - returns a path to a location with split files for a lane

  my $position = 8;
  my $path = $oPackage->lane_archive_path($position);

=head2 lane_qc_path - returns a path to a location for qc output when it is done on split lane files

  my $position = 8;
  my $path = $oPackage->lane_qc_path($position);

=head2 lane_archive_paths - returns a ref to a list of existing lane archives

=head2 lane_qc_paths - returns a ref to a list of existing qc directories for lanes

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Moose::Meta::Class

=item Carp

=item Readonly

=item Cwd

=item File::Spec::Functions

=item Try::Tiny

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 GRL by Andy Brown and Marina Gourtovaia

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
