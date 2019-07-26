package npg_tracking::illumina::run::folder;

use Moose::Role;
use Moose::Meta::Class;
use File::Spec::Functions qw(splitdir catfile catdir);
use Carp;
use Cwd qw/getcwd/;
use Try::Tiny;
use Readonly;
use Math::Random::Secure qw/irand/;

use npg_tracking::util::abs_path qw/abs_path/;
use npg_tracking::Schema;
use npg_tracking::glossary::lane;
use npg_tracking::illumina::run::folder::location;

our $VERSION = '0';

with q{npg_tracking::illumina::run};

Readonly::Scalar my  $DATA_DIR          => q{Data};
Readonly::Scalar my  $QC_DIR            => q{qc};
Readonly::Scalar my  $BASECALL_DIR      => q{BaseCalls};
Readonly::Scalar my  $INTENSITIES_DIR   => q{Intensities};
Readonly::Scalar my  $ANALYSIS_DIR_GLOB => q{_basecalls_};
Readonly::Scalar my  $NO_CAL_DIR        => q{no_cal};
Readonly::Scalar my  $ARCHIVE_DIR       => q{archive};
Readonly::Scalar our $SUMMARY_LINK      => q{Latest_Summary};

Readonly::Hash my %NPG_PATH  => (
  q{runfolder_path}    => 'Path to and including the run folder',
  q{analysis_path}     => 'Path to the top level custom analysis directory',
  q{intensity_path}    => 'Path to the "Intensities" directory',
  q{basecall_path}     => 'Path to the "BaseCalls" directory',
  q{recalibrated_path} => 'Path to the recalibrated qualities directory',
  q{archive_path}      => 'Path to the directory with data ready for archiving',
  q{qc_path}           => 'Path directory with top level QC data',
);

foreach my $path_attr ( keys %NPG_PATH ) {
  has $path_attr => (
    isa           => q{Str},
    is            => q{ro},
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

sub _build_runfolder_path {
  my ($self) = @_;

  my $path = $self->_get_path_from_given_path();
  $path && return $path;

  # get info form DB if there - could be better integrated....
  if ($self->npg_tracking_schema() and
      $self->can(q(id_run)) and  $self->id_run() ) {
    if (! $self->tracking_run->is_tag_set(q(staging))) {
      croak q{NPG tracking reports run }.$self->id_run().q{ no longer on staging}
    }
    if (my $gpath = $self->tracking_run->folder_path_glob and
        my $fname = $self->tracking_run->folder_name) {
      return $self->_get_path_from_glob_pattern(catfile($gpath, $fname));
    }
  }

  return $self->_get_path_from_short_reference();
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
  my $path;
  foreach my $path_method ( qw/ recalibrated_path
                                basecall_path
                                intensity_path
                                archive_path
                                runfolder_path / ) {
    my $has_path_method = q{has_} . $path_method;
    if ($self->$has_path_method()) {
      $path = $self->$path_method();
      last;
    }
  }
  return $path;
}

#############
# private attributes and methods

has q{_folder_path_glob_pattern}  => (
  isa        => q{Str},
  is         => q{ro},
  lazy_build => 1,
);
sub _build__folder_path_glob_pattern {
  my $test_dir = $ENV{TEST_DIR} || q{};
  return $test_dir .
  $npg_tracking::illumina::run::folder::location::FOLDER_PATH_PREFIX_GLOB_PATTERN;
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
  return catdir( @path_components );
}

sub _get_path_from_short_reference {
  my ($self) = @_;

  if ( !$self->can(q(short_reference)) || !$self->short_reference() ) {
    croak q{Not enough information to obtain the path};
  }

  # works out by 'glob'ing the filesystem, the path to the run_folder based on
  # short_reference string

  my $sr = $self->short_reference();
  if ($sr =~ /\a(\d+)\z/xms) {
    $sr = q{_{r,}} . $sr;
  }

  return $self->_get_path_from_glob_pattern(
    $self->_folder_path_glob_pattern() . q{*} . $sr . q[{,_*}]);
}

sub _get_path_from_glob_pattern {
  my ($self, $glob_pattern) = @_;

  my @dir = glob $glob_pattern;
  @dir = grep {-d $_} @dir;

  if ( @dir == 0 ) {
    croak q{No paths to run folder found.};
  }

  my %fs_inode_hash; #ignore multiple paths point to the same folder
  @dir = grep { not $fs_inode_hash { join q(,), stat $_ }++ } @dir;

  if ( @dir > 1 ) {
    croak q{Ambiguous paths for run folder found: } . join qq{\n}, @dir;
  }

  return shift @dir;
}

sub _get_path_from_given_path {
  my ($self) = @_;

  $self->subpath or return;

  my @subpath = splitdir( $self->subpath );
  while (@subpath) {
    my $path = catdir(@subpath);
    if ( -d $path # path of all remaining parts of _given_path (subpath)
            and
         -d catdir($path, q{Config}) # does this directory have a Config Directory
            and
         -d catdir($path, $DATA_DIR)   # a runfolder is likely to have a Data directory
        ) {
       return $path;
    }
    pop @subpath;
  }

  croak q{nothing looks like a run_folder in any given subpath};
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
    croak 'multiple bam_basecall directories in the intensity directory ' .
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

This package might need to have something provide the short_reference method,
either declared in your class or via inheritance from
npg_tracking::illumina::run::short_info, which is the preferred option.

Failure to have provided a short_reference method might cause a run-time error
if your class needs to obtain any paths where a path or subpath was not given
and access to the tracking database is not available.
to glob for it).

In addition to this, you can add an analysis_path, which is the path to the
recalibrated directory, which will be used to construct other paths from.

=head1 SUBROUTINES/METHODS

=head2 runfolder_path

=head2 bam_basecall

=head2 set_bam_basecall_path

 Sets and returns bam_basecall_path. Error if this attribute has
 already been set.

 $obj->set_bam_basecall_path();
 print $obj->bam_basecall_path(); # BAM_basecalls_SOME-RANDOM-NUMBER

 $obj->set_bam_basecall_path(20190122);
 print $obj->bam_basecall_path(); # BAM_basecalls_20190122

=head2 analysis_path

=head2 intensity_path - ro accessor to the intensity level path

=head2 basecall_path - ro accessor to the BaseCalls level directory path

=head2 recalibrated_path - ro accessor to the recalibrated level directory path

=head2 archive_path - ro accessor to the archive level directory path

=head2 subpath

One of given paths from which the run folder path might be inferred.
Might be undefined.

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

=item Math::Random::Secure

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Andy Brown

=item Marina Gourtovaia

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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
