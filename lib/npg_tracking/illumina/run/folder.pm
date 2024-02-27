package npg_tracking::illumina::run::folder;

use Moose::Role;
use Moose::Util::TypeConstraints;
use File::Spec::Functions qw/splitdir catfile catdir/;
use Carp;
use Cwd qw/getcwd/;
use Try::Tiny;
use Readonly;
use Math::Random::Secure qw/irand/;
use List::Util qw/first/;

use npg_tracking::util::types;
use npg_tracking::util::abs_path qw/abs_path/;
use npg_tracking::Schema;
use npg_tracking::glossary::lane;
use npg_tracking::util::config qw/get_config_staging_areas/;

our $VERSION = '0';

with 'npg_tracking::illumina::run';


# Top-level directory where instruments create runfolders
Readonly::Scalar my  $INCOMING_DIR      => q{/incoming/};

# Directories created by Illumina software
Readonly::Scalar my  $DATA_DIR          => q{Data};
Readonly::Scalar my  $CONFIG_DIR        => q{Config};
Readonly::Scalar my  $BASECALL_DIR      => q{BaseCalls};
Readonly::Scalar my  $INTENSITIES_DIR   => q{Intensities};
Readonly::Scalar my  $DRAGEN_ANALYSIS_DIR => q{Analysis};

# Directories and links created by NPG software
Readonly::Scalar my  $ANALYSIS_DIR_GLOB => q{_basecalls_};
Readonly::Scalar my  $NO_CAL_DIR        => q{no_cal};
Readonly::Scalar my  $ARCHIVE_DIR       => q{archive};
Readonly::Scalar my  $NO_ARCHIVE_DIR    => q{no_archive};
Readonly::Scalar my  $PP_ARCHIVE_DIR    => q{pp_archive};
Readonly::Scalar our $SUMMARY_LINK      => q{Latest_Summary};
Readonly::Scalar my  $QC_DIR            => q{qc};

my $config=get_config_staging_areas();
# The prod. value of prefix is '/export/esa-sv-*' in Feb. 2024
# Example prod. run folder path
# /export/esa-sv-20240201-01/IL_seq_data/incoming/20240124_LH00210_0016_B225GWVLT3
Readonly::Scalar my $STAGING_AREAS_PREFIX => $config->{'prefix'} || q();
Readonly::Scalar my $FOLDER_PATH_PREFIX_GLOB_PATTERN =>
                                               "$STAGING_AREAS_PREFIX/IL*/*/";

Readonly::Hash my %NPG_PATH  => (
  q{runfolder_path}    => 'Path to and including the run folder',
  q{dragen_analysis_path} => 'Path to the DRAGEN analysis directory',
  q{intensity_path}    => 'Path to the "Intensities" directory',
  q{basecall_path}     => 'Path to the "BaseCalls" directory',
  q{analysis_path}     => 'Path to the top level custom analysis directory',
  q{recalibrated_path} => 'Path to the recalibrated qualities directory',
  q{archive_path}      => 'Path to the directory with data ready for archiving',
  q{no_archive_path}   => 'Path to the directory with data not to be archived',
  q{pp_archive_path}   => 'Path to the archive directory for third party portable pipelines',
  q{qc_path}           => 'Path directory with top level QC data',
);

has q{id_run}           => (
  isa           => q{NpgTrackingRunId},
  is            => q{ro},
  required      => 0,
  lazy_build    => 1,
  documentation => 'Integer identifier for a sequencing run',
);
sub _build_id_run {
  my ($self) = @_;

  my $id_run;

  if ($self->npg_tracking_schema()) {
    if (!$self->has_run_folder()) {
      $self->run_folder(); # Force the build
    }
    my $rs = $self->npg_tracking_schema()->resultset('Run')
             ->search({folder_name => $self->run_folder()});
    if ($rs->count == 1) {
      $id_run = $rs->next()->id_run();
    }
  }

  # When no id_run is set, attempt to parse an id_run from the experiment name
  # recorded in the Illumina XML file.
  # We embed additional information in NovaSeqX samplesheets which have no
  # meaning here. See L<Samplesheet generator|npg::samplesheet::novaseq_xseries>
  if ( !$id_run && $self->can('experiment_name') && $self->experiment_name() ) {
    ($id_run, undef) = $self->experiment_name() =~ m{
      \A
      [\s]*
      ([\d]+)     # id_run
      ([\w\d\s]*) # instrument name or other embedded info
      \Z
    }xms;
  }

  if( !$id_run ) {
    croak q[Unable to identify id_run with data provided];
  }

  return $id_run;
}


my $run_folder_subtype_name = __PACKAGE__.q(::folder);
subtype $run_folder_subtype_name
  => as 'Str'
  => where { splitdir($_)==1 };

has q{run_folder}        => (
  isa           => $run_folder_subtype_name,
  is            => q{ro},
  lazy_build    => 1,
  documentation => 'Directory name of the run folder',
);
sub _build_run_folder {
  my ($self) = @_;
  ($self->subpath or $self->has_id_run)
      or croak 'Need a path or id_run to work out a run_folder';
  return first {$_ ne q()} reverse File::Spec->splitdir($self->runfolder_path);
}


has q{npg_tracking_schema} => (
  isa        => q{Maybe[npg_tracking::Schema]},
  is         => q{ro},
  lazy_build => 1,
);
sub _build_npg_tracking_schema {
  my $schema;
  try {
    $schema = npg_tracking::Schema->connect();
  } catch {
    carp qq{Unable to connect to NPG tracking DB for faster globs.\n};
  };
  return $schema;
}


foreach my $path_attr ( keys %NPG_PATH ) {
  has $path_attr => (
    isa           => q{Str},
    is            => q{ro},
    predicate     => 'has_' . $path_attr,
    lazy_build    => 1,
    documentation => $NPG_PATH{$path_attr},
  );
}

has q{bam_basecall_path}  => (
  isa           => q{Str},
  is            => q{ro},
  predicate     => 'has_bam_basecall_path',
  writer        => '_set_bbcall_path',
  documentation => 'Path to the "BAM Basecalls" directory',
);
sub set_bam_basecall_path {
  my ($self, $path, $full_path_flag) = @_;
  $self->has_bam_basecall_path and croak
    'bam_basecall is already set to ' . $self->bam_basecall_path();
  if ($full_path_flag) {
    $self->_set_bbcall_path($path);
  } else {
    $path = q[BAM] . $ANALYSIS_DIR_GLOB . (defined $path ? $path : irand());
    $path = catdir($self->intensity_path, $path);
    $self->_set_bbcall_path($path);
  }
  return $self->bam_basecall_path;
}

sub _build_runfolder_path {
  my ($self) = @_;

  my $path;
  my $runfolder_name = $self->has_run_folder ? $self->run_folder : undef;

  # Try to use one of paths (if any) supplied via a constructor to figure out
  # the location of the run folder directory. This method examines the
  # directory structure looking for subdirectories, which normally exist in
  # the Illumina run folder.
  if ($self->subpath()) {
    $path = _get_path_from_given_path($self->subpath());
  }

  # Try to get the run folder name and glob from the database and then glob
  # for the run folder directory. Limit this search to run folders that
  # are known to be on staging.
  if ((not $path) and $self->npg_tracking_schema()) {
    # The code below needs run ID, so 'id_run' will be built if not given.
    if (not $self->tracking_run->is_tag_set(q(staging))) {
      croak sprintf 'NPG tracking reports run %i no longer on staging',
        $self->id_run;
    }
    my $db_runfolder_name = $self->tracking_run->folder_name;
    if ($db_runfolder_name) {
      if ($runfolder_name and ($db_runfolder_name ne $runfolder_name)) {
        # Probably this is an error. Warn for now.
        carp sprintf 'Inconsistent db and given run folder name: %s, %s',
          $db_runfolder_name, $runfolder_name;
      }
      if (my $gpath = $self->tracking_run->folder_path_glob) {
        $path = $self->_get_path_from_glob_pattern(
          catfile($gpath, $db_runfolder_name)
        );
      }
    }
  }

  # Try to use the runfolder name, if set via the constructor, and the
  # staging area prefix from the 'npg_tracking' configuration file to
  # glob the file system. This is the most expensive file system glob,
  # so doing this as the last resort. 
  if ((not $path) and $runfolder_name) {
    $path = $self->_get_path_from_glob_pattern(
      $self->_folder_path_glob_pattern() . $runfolder_name
    );
  }

  # Most likely, the code execution will not advance this far without $path
  # being computed. In case of problems an error will be raised by one of
  # the methods called above. Returning an undefined path will trigger an
  # error since the 'runfolder_path' attribute is defined as a string.
  # Raising an error here to help with deciphering error messages.

  $path or croak 'Failed to infer runfolder_path';

  return $path;
}

sub _build_analysis_path {
  my ($self) = @_;

  if ($self->has_bam_basecall_path) {
    return $self->bam_basecall_path;
  }
  if ($self->has_archive_path) {
    return _infer_analysis_path($self->archive_path, 2);
  }
  my $path = q{};
  try {
    $path = _infer_analysis_path($self->recalibrated_path, 1);
  };

  return $path;
}

sub _build_intensity_path {
  my ($self) = @_;
  return catdir($self->runfolder_path(), $DATA_DIR, $INTENSITIES_DIR);
}

sub _build_dragen_analysis_path {
  my $self = shift;
  return catdir($self->runfolder_path(), $DRAGEN_ANALYSIS_DIR);
}

sub _build_basecall_path {
  my ($self) = @_;
  return catdir($self->intensity_path(), $BASECALL_DIR);
}

sub _build_recalibrated_path {
  my ($self) = @_;

  # Try to get the path either from a known immediate upstream or
  # downstream.

  if ($self->has_bam_basecall_path) {
    # Not checking whether the directory exists! Should we?
    return catdir($self->bam_basecall_path, $NO_CAL_DIR );
  }

  my $rf_path = $self->runfolder_path();
  my $summary_link = catfile($rf_path, $SUMMARY_LINK );
  if (-l $summary_link ) {
    my $path = readlink $summary_link;
    if ($path) {
      $path =~ s/\/\Z//xms;
      if ($path !~ /\A\Q$rf_path\E/xms) {
        $path = catfile($rf_path, $path);
      }
      -d $path or croak "$path is not a directory, cannot be the recalibrated path";
      $path =~ /\/$NO_CAL_DIR\Z/xms or carp
        "Warning: recalibrated directory found via $SUMMARY_LINK link ".
        "is not called $NO_CAL_DIR";
      return $path;
    }
  }
  # Still here?
  carp "Summary link $summary_link does not exist or is not a link";

  if ($self->has_archive_path) {
    my $path = _infer_analysis_path($self->archive_path, 1);
    if ($path !~ /\/$NO_CAL_DIR\Z/smx) {
      carp "recalibrated_path $path derived from archive_path " .
           "does not end with $NO_CAL_DIR";
    }
    return $path;
  }

  # Not checking whether the directory exists! Should we?
  return catdir($self->_get_analysis_path_from_glob(), $NO_CAL_DIR);
}

sub _build_archive_path {
  my ($self) = @_;
  return $self->recalibrated_path() . q{/} . $ARCHIVE_DIR;
}

sub _build_no_archive_path {
  my ($self) = @_;
  return $self->analysis_path() . q{/} . $NO_ARCHIVE_DIR;
}

sub _build_pp_archive_path {
  my ($self) = @_;
  return $self->analysis_path() . q{/} . $PP_ARCHIVE_DIR;
}

sub _build_qc_path {
  my ($self) = @_;
  return $self->archive_path() . q{/} . $QC_DIR;
}

has q{subpath} => (
  isa        => q{Maybe[Str]},
  is         => q{ro},
  lazy_build => 1,
);
sub _build_subpath {
  my $self = shift;

  foreach my $path_method ( qw/ recalibrated_path
                                basecall_path
                                intensity_path
                                archive_path
                                runfolder_path / ) {
    my $has_path_method = q{has_} . $path_method;
    if ($self->$has_path_method()) {
      return $self->$path_method();
    }
  }

  return;
}

#############
# private attributes and methods

has q{_folder_path_glob_pattern}  => (
  isa        => q{Str},
  is         => q{ro},
  default    => $FOLDER_PATH_PREFIX_GLOB_PATTERN,
);

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
  return catdir( @path_components );
}

sub _get_path_from_glob_pattern {
  my ($self, $glob_pattern) = @_;

  my @dir = glob $glob_pattern;
  @dir = grep {-d $_} @dir;

  if ( @dir == 0 ) {
    croak q{No paths to run folder found};
  }

  my %fs_inode_hash; # ignore multiple paths point to the same folder
  @dir = grep { not $fs_inode_hash { join q(,), stat $_ }++ } @dir;
  if ( @dir > 1 ) {
    # Ignore the case when some of the directories are in the /incoming/
    # folder - these are likely to be spurious directories created by
    # instruments well after the run was mirrored and moved to /analysis/
    # or even to /outgoing/.
    my @dir_not_incoming = grep { $_ !~ /$INCOMING_DIR/xms } @dir;
    if (!@dir_not_incoming || (@dir_not_incoming > 1)) {
      croak q{Ambiguous paths for run folder found: } . join qq{\n}, @dir;
    }
    @dir = @dir_not_incoming;
  }

  return shift @dir;
}

sub _get_path_from_given_path {
  my ($subpath) = @_;

  my @dirs = splitdir($subpath);
  while (@dirs) {
    my $path = catdir(@dirs);
    if ( -d $path
            and
         -d catdir($path, $CONFIG_DIR) # does this directory have a Config Directory
            and
         -d catdir($path, $DATA_DIR)   # a runfolder is likely to have a Data directory
        ) {
       return $path;
    }
    pop @dirs;
  }

  croak qq{Nothing looks like a run folder in any subpath of $subpath};
}

sub _get_analysis_path_from_glob {
  my $self = shift;

  my $glob_expression = join q[/], $self->intensity_path(),
                                   q[*] . $ANALYSIS_DIR_GLOB . q[*];
  my @bbcal_dirs = glob $glob_expression;
  if (!@bbcal_dirs) {
    croak 'bam_basecall directory not found in the intensity directory ' .
          $self->intensity_path();
  }
  if (@bbcal_dirs > 1) {
    croak 'Multiple bam_basecall directories in the intensity directory ' .
          $self->intensity_path();
  }

  return $bbcal_dirs[0];
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
    analysis_path => q{/recalibrated/directory/below/run_folder},
  });

=head1 DESCRIPTION

This package might need to have something provide the run_folder accessor
either declared in your class or via inheritance from
npg_tracking::illumina::run::short_info, which is the preferred option.

Failure to have provided the runfolder accessor  might cause a run-time error
if your class needs to obtain any paths where a path or subpath was not given
and access to the tracking database is not available.

In addition to this, you can add an analysis_path, which is the path to the
recalibrated directory, which will be used to construct other paths from.

=head1 SUBROUTINES/METHODS

=head2 id_run

An attribute, NPG run identifier. If the value is not supplied, an attempt
to build it is made. 

If access to a run tracking database is available and the database contains
the run record and the run folder name is defined in the database record and
the run_folder attribute is defined or can be built, then its value is used
to retrieve the id_run value from the database.

If 'experiment_name' accessor is provided by the class that inherits from
this role, then, in the absence of a database record, an attempt is made to parse
out run ID from the value returned by the 'experiment_name' accessor. See
npg_tracking::illumina::run::long_info for the implementation of this accessor.

=head2 run_folder

An attribute, run folder name, can be set in the constructor or lazy-built.

=head2 npg_tracking_schema

npg_tracking::Schema db handle object, which is allowed to be assigned an
undefined value. An attempt to build this attribute is made. In case of a
failure an undefined value is assigned.

=head2 runfolder_path

=head2 bam_basecall_path

=head2 set_bam_basecall_path
 
Sets and returns bam_basecall_path. Error if this attribute has
already been set.
 
  $obj->set_bam_basecall_path();
  print $obj->bam_basecall_path(); # BAM_basecalls_SOME-RANDOM-NUMBER

=head2 analysis_path

=head2 intensity_path - ro accessor to the intensity level path

=head2 basecall_path - ro accessor to the BaseCalls level directory path

=head2 dragen_analysis_path

The default path for the output of the on-board DRAGEN analysis. This path
might exist for runs performed on NovaSeqX Illumina instruments. 

=head2 recalibrated_path - ro accessor to the recalibrated level directory path

=head2 analysis_path

=head2 archive_path - ro accessor to the archive level directory path

=head2 no_archive_path - ro accessor to the no_archive level directory path

=head2 pp_archive_path

Path to the archive directory for third party portable pipelines.

=head2 subpath

One of given paths from which the run folder path might be inferred.
Might be undefined.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Moose::Util::TypeConstraints

=item Carp

=item Readonly

=item Cwd

=item File::Spec::Functions

=item Try::Tiny

=item Math::Random::Secure

=item List::Util

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Andy Brown

=item Marina Gourtovaia

=item Martin Pollard

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013,2014,2015,2018,2019,2020,2023,2024 Genome Research Ltd.

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
