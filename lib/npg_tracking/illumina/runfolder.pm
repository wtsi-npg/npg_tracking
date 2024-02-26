package npg_tracking::illumina::runfolder;

########
# 04 January 2018
# Copied from svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/data_handling/trunk/lib/srpipe/runfolder.pm
#

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

our $VERSION = '0';

=head1 NAME

npg_tracking::illumina::runfolder

=head1 SYNOPSIS

  my $oRunfolder = npg_tracking::illumina::runfolder->new(id_run => 3220);
  chdir $oRunfolder->runfolder_path;

  my $oRunfolder = npg_tracking::illumina::runfolder->new(
    runfolder_path => '/staging/IL29/incoming/090721_IL29_3379/');
  my $id = $oRunfolder->id_run; # 3379

=head1 DESCRIPTION

Utility to locate and extract run information from the Illumina runfolder
directory heirarchy and from the files within it.

=head1 SUBROUTINES/METHODS

=cut

with 'npg_tracking::illumina::run::folder';
with 'npg_tracking::illumina::run::long_info';

__PACKAGE__->meta->make_immutable;

1;

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David K. Jackson, E<lt>david.jackson@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018,2019,2024 Genome Research Ltd.

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
