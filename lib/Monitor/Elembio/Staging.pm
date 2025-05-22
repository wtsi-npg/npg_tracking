package Monitor::Elembio::Staging;

use Carp;
use Cwd 'abs_path';
use File::Basename;
use Readonly;
use File::Spec::Functions 'catfile';
use Exporter;
use Perl6::Slurp;
use JSON;
use Monitor::Elembio::Enum qw( 
  $RUN_MANIFEST_FILE
  $RUN_PARAM_FILE
  $RUN_STANDARD
  $RUN_TYPE
);

our @ISA= qw( Exporter );
our @EXPORT = qw( find_run_folders );

Readonly::Scalar my $RUN_MANIFEST_GLOB => 'AV*/**/' . $RUN_MANIFEST_FILE;

our $VERSION = '0';

=head1 NAME

Monitor::Elembio::Staging

=head1 VERSION

=head1 SYNOPSIS

  use Monitor::Elembio::Staging qw( find_run_folders );

=head1 DESCRIPTION

Utilities to interrogate the staging area designated to an Elembio instrument.

=head1 SUBROUTINES/METHODS

=head2 find_run_folders

Find valid run folders for Elembio runs in a top folder (or staging area).
Folders for non-sequencing runs are excluded.
A valid run folder has RunManifest.json and RunParameters.json files.

The path pattern matches [staging_area]/AV*/[run_folder]

A list of run folder paths is returned.
=cut
sub find_run_folders {
  my $staging_area = shift;

  croak('Top level staging path required') if !$staging_area;
  croak("$staging_area not a directory") if !-d $staging_area;

  my @run_folders = ();
  # RunManifest will be present in real runs
  my $manifest_pattern = catfile($staging_area, $RUN_MANIFEST_GLOB);
  foreach my $run_manifest_file ( glob $manifest_pattern ) {
    my $runfolder_path = dirname(abs_path($run_manifest_file));
    my $run_parameters_file = catfile($runfolder_path, $RUN_PARAM_FILE);
    if (! -e $run_parameters_file) {
      croak("No RunParameters.json file in $runfolder_path");
    }
    my $json_params_data = decode_json(slurp $run_parameters_file);
    if ($json_params_data->{$RUN_TYPE} eq $RUN_STANDARD) {
      push @run_folders, $runfolder_path;
    }
  }
  return @run_folders;
}

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Carp

=item Cwd

=item File::Basename

=item File::Spec::Functions

=item Exporter

=item Monitor::Elembio::Enum

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Marco M. Mosca

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2025 Genome Research Ltd.

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

=cut
