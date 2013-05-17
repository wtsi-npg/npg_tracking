#############
# $Id: folder.pm 16549 2013-01-23 16:49:39Z mg8 $
# Created By: ajb
# Last Maintained By: $Author: mg8 $
# Created On: 2009-10-01
# Last Changed On: $Date: 2013-01-23 16:49:39 +0000 (Wed, 23 Jan 2013) $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/illumina/run/folder.pm $

package npg_tracking::illumina::run::folder;

use strict;
use warnings;
use Moose::Role;
use Moose::Meta::Class;
use File::Spec::Functions qw(splitdir catfile catdir);
use Carp qw(carp cluck croak confess);
use Cwd;

use Try::Tiny;
use npg_tracking::Schema;
use npg_tracking::glossary::lane;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 16549 $ =~ /(\d+)/mxs; $r; };

with 'npg_tracking::illumina::run::folder::location';

Readonly::Scalar our $TAG_QSEQS     => q{tag_qseqs};
Readonly::Scalar our $QC_DIR        => q{qc};
Readonly::Scalar our $BASECALL_DIR  => q{BaseCalls};
Readonly::Scalar our $BASECALL_MATCH => q{_basecalls_};
Readonly::Scalar our $ARCHIVE_DIR   => q{archive};
Readonly::Scalar our $SUMMARY_LINK  => q{Latest_Summary};
Readonly::Array  our @RECALIBRATED_DIR_MATCH  => ( qw{GERALD PB_cal no_cal} );
Readonly::Array  our @BUSTARD_DIR_MATCH       => ( q{Bustard}, $BASECALL_DIR, $BASECALL_MATCH );
Readonly::Array  our @INTENSITY_DIR_MATCH     => ( qw{Intensities Firecrest} );

##############
# public methods

Readonly::Array our @ORDER_TO_ASSESS_SUBPATH_ASSIGNATION => (
    qw{
      recalibrated_path basecall_path bustard_path intensity_path
      data_path pb_cal_path qc_path archive_path tag_qseqs_path
      runfolder_path
    }
  );

has q{analysis_path}      => ( isa => q{Str}, is => q{ro}, lazy_build => 1,
                                 documentation => qq{Path to the analysis directory to be used, generally equivalent to recalibrated_path.\nIf not set on construction, will default to an empty string - you should request recalibrated_path}, );

has q{data_path}          => ( isa => q{Str}, is => q{ro}, lazy_build => 1, writer => q{_set_data_path},
                                 documentation => 'Path to the "Data" directory',);
has q{reports_path}       => ( isa => q{Str}, is => q{ro}, lazy_build => 1,
                                 documentation => 'Path to the "reports" directory',);
has q{intensity_path}     => ( isa => q{Str}, is => q{ro}, lazy_build => 1, writer => q{_set_intensity_path},
                                 documentation => 'Path to the "Intensities" directory',);
has q{bustard_path}       => ( isa => q{Str}, is => q{ro}, lazy_build => 1, writer => q{_set_bustard_path},
                                 documentation => 'Path to the "Bustard" directory',);
has q{basecall_path}      => ( isa => q{Str}, is => q{ro}, lazy_build => 1, writer => q{_set_basecall_path},
                                 documentation => 'Path to the "Basecalls" directory',);
has q{bam_basecall_path}  => ( isa => q{Str}, is => q{ro}, predicate => 'has_bam_basecall_path',  writer => q{_set_bam_basecall_path},
                                 documentation => 'Path to the "BAM Basecalls" directory',);
has q{dif_files_path}      => ( isa => q{Str}, is => q{ro}, predicate => 'has_dif_files_path',  writer => q{_set_dif_files_path},
                                 documentation => 'Path to the "dif files" directory',);
has q{recalibrated_path}  => ( isa => q{Str}, is => q{ro}, lazy_build => 1, writer => q{_set_recalibrated_path},
                                 documentation => 'Path to the recalibrated qualities directory (e.g. "GERALD")',);
has q{pb_cal_path}        => ( isa => q{Str}, is => q{ro}, lazy_build => 1, writer => q{_set_pb_cal_path},
                                 documentation => 'Path to the PB_cal directory',);
has q{tag_qseqs_path}     => ( isa => q{Str}, is => q{ro}, lazy_build => 1, writer => q{_set_tag_qseqs_path},
                                 documentation => 'Path to the tagged qseq directory',);
has q{archive_path}       => ( isa => q{Str}, is => q{ro}, lazy_build => 1, writer => q{_set_archive_path},
                                 documentation => 'Path to the output ready for archiving directory',);
has q{qc_path}            => ( isa => q{Str}, is => q{ro}, lazy_build => 1,
                                 documentation => 'Path to the QC directory',);
has q{score_path}         => ( isa => q{Str}, is => q{ro}, lazy_build => 1,
                                 documentation => 'Path to the directory containing score files',);
has q{qseq_location_path} => ( isa => q{Str}, is => q{ro}, lazy_build => 1, writer => q{_set_qseq_location_path},
                                 documentation => 'Path to the directory which may be containing calibrated qseq files',);

has q{npg_tracking_schema} => ( isa => q{Maybe[npg_tracking::Schema]}, is => q{ro}, lazy_build => 1,
                                 documentation => 'NPG tracking DBIC schema', );

#############
# private methods
has q{subpath} => ( isa => q{Str}, is => q{ro}, predicate => q{has_subpath}, writer => q{_set_subpath});

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

#############
# builders

sub _build_npg_tracking_schema {
  my $schema;
  try {
    $schema = npg_tracking::Schema->connect();
  } catch {
    warn qq{Unable to connect to NPG tracking DB for faster globs.\n};
  };
  return $schema;
}

sub _build_analysis_path {
  my ($self) = @_;
  return q{};
}

sub _build_data_path {
  my ($self) = @_;
  return $self->runfolder_path() . q{/Data};
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
  return $self->data_path() . q{/reports};
}

sub _build_tag_qseqs_path {
  my ($self) = @_;
  return $self->recalibrated_path() . q{/} . $TAG_QSEQS;
}

sub _build_archive_path {
  my ($self) = @_;
  return $self->recalibrated_path() . q{/} . $ARCHIVE_DIR;
}

sub _build_qc_path {
  my ($self) = @_;
  return $self->archive_path() . q{/} . $QC_DIR;
}

sub _build_score_path {
  my ($self) = @_;
  return $self->recalibrated_path() . q{/Stats/};
}

sub _build_qseq_location_path {
  my ($self) = @_;
  return $self->recalibrated_path() . q{/Temp/Custom};
}

sub _populate_directory_paths {
  my ($self) = @_;

  # if recalibrated_path has been provided/populated, use this
  if ( $self->has_recalibrated_path() ) {
    return $self->_process_path($self->recalibrated_path());
  }

  # if an analysis_path has been provided, then use this
  if ( $self->has_analysis_path() && $self->analysis_path() ) {
    return $self->_process_path($self->analysis_path());
  }

  # else try to find the recalibrated analysis path
  my $path = $self->_find_recalibrated_directory_path($self->runfolder_path());
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

  my $intensity_path     = $self->runfolder_path() . qq{/Data/$intensity_dir};
  my $bustard_path       = qq{$intensity_path/$bustard_dir};
  my $basecall_path      = qq{$intensity_path/$BASECALL_DIR};
  my $recalibrated_path = $use_bustard_as_recalibrated ?  $bustard_path
                        :                                 qq{$bustard_path/$recalibrated_dir}
                        ;

  if (!$self->has_data_path())         { $self->_set_data_path($self->runfolder_path() . q{/Data}); };
  if (!$self->has_intensity_path())    { $self->_set_intensity_path($intensity_path); };
  if (!$self->has_bustard_path())      { $self->_set_bustard_path($bustard_path); };
  if (!$self->has_basecall_path())     { $self->_set_basecall_path($basecall_path); };
  if (!$self->has_pb_cal_path())       { $self->_set_pb_cal_path($bustard_path . q{/PB_cal}); };
  if (!$self->has_recalibrated_path()) { $self->_set_recalibrated_path($recalibrated_path); };

  if ($self->can(q{verbose}) && $self->verbose()) {
    foreach my $dir (qw{data intensity bustard basecall recalibrated tag_qseqs pb_cal}) {
      my $subpath_dir = $dir . q{_path};
      carp qq{$dir : } . $self->$subpath_dir();
    }
  }

  return 1;
}


sub _find_recalibrated_directory_path {
  my ( $self, $path ) = @_;
  my $recalibrated_path;

  # have users declared analysis_path, try this
  if ($self->has_analysis_path()) {
    $recalibrated_path = $self->_recalibrated_path( $self->analysis_path() );
  }

  if ($recalibrated_path) {
    return $recalibrated_path;
  }

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

  if ( -l qq{$path/$SUMMARY_LINK}) {
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
        my @temp_dirs = glob $rf_path . qq{/Data/*$int_dir_name*/$bustard_dir_name*/$recal_dir_name*};
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
      push @dirs, glob $rf_path . qq{/Data/*$int_dir_name*/$bustard_dir_name*};
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

    if (
       -d $path # path of all remaining parts of the directory
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
            -d catdir($path, q{Data}) # a runfolder is likely to have a Data directory
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

=head1 VERSION

$Revision: 16549 $

=head1 SYNOPSIS

  package MyPackage;
  use Moose;
  with qw{npg_tracking::illumina::run::short_info
          npg_tracking::illumina::run::folder};

  my $oPackage = MyPackage->new({
    path => q{/string/to/a/run_folder},
  });

  my $oPackage = MyPackage->new({
    subpath => q{/string/to/a/run_folder/dir/below/it},
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

Failure to have provided a short_reference method WILL cause a run_time error if your class needs to obtain
any paths where a path or subpath was not given in object construction (i.e. it wants to try to use id_run
to glob for it). The error will be along the lines of:

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

=head2 analysis_path - can be given in object constructor, and this will be used to work out other directory paths

=head2 data_path - ro accessor to the Data directory subpath
=head2 intensity_path - ro accessor to the intensity level directory subpath
=head2 bustard_path - ro accessor to the Bustard level directory subpath
=head2 basecall_path - ro accessor to the BaseCalls level directory subpath
=head2 recalibrated_path - ro accessor to the recalibrated level directory subpath
=head2 tag_qseqs_path - ro accessor to the tag_qseqs level directory subpath
=head2 archive_path - ro accessor to the archive level directory subpath
=head2 qc_subpath - ro accessor to the qc level directory subpath

  my $sSubPath = $oPackage->xxx_path();

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

=item Carp

=item Readonly

=item Cwd

=item File::Spec::Functions

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

$Author: mg8 $

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 Andy Brown (ajb@sanger.ac.uk)

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
