#############
# Created By: dj3
# Created On: 2011-09-12

package npg_tracking::illumina::run::folder::location;

use strict;
use warnings;
use Moose::Role;
use Carp qw(croak);
use Cwd;
use File::Spec::Functions;
use Readonly;

our $VERSION = '0';

Readonly::Array our @STAGING_AREAS_INDEXES => 18 .. 55;
Readonly::Array our @STAGING_AREAS => map { "/nfs/sf$_" } @STAGING_AREAS_INDEXES;

Readonly::Scalar our $HOST_GLOB_PATTERN => q[/nfs/sf{].join(q(,), @STAGING_AREAS_INDEXES).q[}];
Readonly::Scalar our $DIR_GLOB_PATTERN  => q[{IL,HS}*/*/]; #'/staging/IL*/*/'; #
Readonly::Scalar our $FOLDER_PATH_PREFIX_GLOB_PATTERN
    => "$HOST_GLOB_PATTERN/$DIR_GLOB_PATTERN";

with q[npg_tracking::illumina::run];

##############
# public methods

has q{runfolder_path}     => ( isa => q{Str}, is => q{ro}, lazy_build => 1,
                                 documentation => 'Path to and including the run folder',);

#############
# private methods

has q{_folder_path_glob_pattern}  => ( isa => q{Str}, is => q{ro}, lazy_build => 1 );

# works out by 'glob'ing the filesystem, the path to the run_folder based on short_reference string
sub _get_path_from_short_reference {
  my ($self) = @_;
  my $sr = $self->short_reference();
  if ($sr =~ /\a(\d+)\z/xms) {
    $sr = q{_{r,}} . $sr;
  }

  return $self->_get_path_from_glob_pattern($self->_folder_path_glob_pattern() . q{*} . $sr . q[{,_*}]);
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

#############
# builders

sub _build_runfolder_path {
  my ( $self ) = @_;

  if ( $self->can(q(get_path_from_given_path)) and $self->can(q(_given_path)) and  $self->_given_path() ) {
    return $self->get_path_from_given_path();
  }

  # get info form DB if there - could be better integrated....
  if ($self->can(q(npg_tracking_schema)) and  $self->npg_tracking_schema() and
      $self->can(q(id_run))              and  $self->id_run() ) {
    if (! $self->tracking_run->is_tag_set(q(staging))) {
      croak q{NPG tracking reports run }.$self->id_run().q{ no longer on staging}
    }
    if (my $gpath = $self->tracking_run->folder_path_glob and
           my $fname = $self->tracking_run->folder_name) {
      return $self->_get_path_from_glob_pattern(catfile($gpath, $fname));
    }
  }

  if ( !$self->can(q(short_reference)) || !$self->short_reference() ) {
    croak q{Not enough information to obtain the path};
  }

  return $self->_get_path_from_short_reference();
}

sub _build__folder_path_glob_pattern {
  my $test_dir = $ENV{TEST_DIR} || q{};
  return $test_dir . $FOLDER_PATH_PREFIX_GLOB_PATTERN;
}



1;
__END__

=head1 NAME

npg_tracking::illumina::run::folder::location

=head1 VERSION

=head1 SYNOPSIS

  package MyPackage;
  use Moose;
  with qw{npg_tracking::illumina::run::short_info
          npg_tracking::illumina::run::folder::location};

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

David K. Jackson

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL by David K. Jackson (david.jackson@sanger.ac.uk)

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
