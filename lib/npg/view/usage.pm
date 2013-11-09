#########
# Author:        rmp
# Maintainer:    $Author: gq1 $
# Created:       2008-04-21
# Last Modified: $Date: 2010-05-04 15:28:42 +0100 (Tue, 04 May 2010) $
# Id:            $Id: usage.pm 9207 2010-05-04 14:28:42Z gq1 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg/view/usage.pm $
#
package npg::view::usage;
use strict;
use warnings;
use base qw(npg::view);
use npg_tracking::illumina::run::folder::location;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 9207 $ =~ /(\d+)/smx; $r; };

sub list {
  my ($self) = @_;
  my $model      = $self->model();
  $model->{staging_area_indexes} = [@npg_tracking::illumina::run::folder::location::STAGING_AREAS_INDEXES];
  return;
}

1;
__END__

=head1 NAME

npg::view::usage

=head1 VERSION

$LastChangedRevision: 9207 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 list

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict
warnings
base
npg::view
npg_tracking::illumina::run::folder::location

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

$Author: Roger M Pettett$

=head1 LICENSE AND COPYRIGHT

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
