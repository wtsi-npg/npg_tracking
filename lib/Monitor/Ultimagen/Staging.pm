package Monitor::Ultimagen::Staging;

use strict;
use warnings;
use Carp;
use Cwd 'abs_path';
use File::Basename;
use Readonly;
use File::Spec::Functions 'catfile';
use Exporter;

our @ISA= qw( Exporter );
our @EXPORT = qw( find_run_folders );

Readonly::Scalar my $RUN_LIBRARYINFO_GLOB => 'Runs/**/*_LibraryInfo.xml';

our $VERSION = '0';

=head1 NAME

Monitor::Ultimagen::Staging

=head1 VERSION

=head1 SYNOPSIS

  use Monitor::Ultimagen::Staging qw( find_run_folders );
  my @folders = find_run_folders($staging_area);
 
=head1 DESCRIPTION

Utilities to interrogate the staging area designated to an Ultimagen instrument.

=head1 SUBROUTINES/METHODS

=head2 find_run_folders

Find valid run folders for Ultimagen runs in a top folder (or staging area).
A valid run folder has RunID_LibraryInfo.xml file.

The path pattern matches [staging_area]/Runs/[run_folder]

A list of run folder paths is returned.
=cut
sub find_run_folders {
  my $staging_area = shift;

  croak('Top level staging path required') if !$staging_area;
  croak("$staging_area not a directory") if !-d $staging_area;

  my @run_folders = ();
  my $libraryinfo_pattern = catfile($staging_area, $RUN_LIBRARYINFO_GLOB);
  foreach my $libraryinfo_file ( glob $libraryinfo_pattern ) {
    my $runfolder_path = dirname(abs_path($libraryinfo_file));
    push @run_folders, $runfolder_path;
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
