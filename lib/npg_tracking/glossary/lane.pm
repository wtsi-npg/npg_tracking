#############
# Created By: Marina Gourtovaia
# Maintainer: $Author: mg8 $
# Created On: 23 April 2010
# Last Modified: $Date: 2013-01-23 16:49:39 +0000 (Wed, 23 Jan 2013) $
# $Id: lane.pm 16549 2013-01-23 16:49:39Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/glossary/lane.pm $

package npg_tracking::glossary::lane;

use Moose::Role;
use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 16549 $ =~ /(\d+)/mxs; $r; };

use npg_tracking::util::types;

has 'position'    => (isa       => 'NpgTrackingLaneNumber',
                      is        => 'rw',
                      required  => 1,
                     );

sub lane_archive {
    my $self = shift;
    return q[lane].$self->position;
}

1;

__END__

=head1 NAME

npg_tracking::glossary::lane

=head1 VERSION

$LastChangedRevision: 16549 $

=head1 SYNOPSIS

=head1 DESCRIPTION

lane interface

=head1 SUBROUTINES/METHODS

=head2 position - position or lane number, an integer from 1 to 8 inclusive

=head2 lane_archive - the name of the directory with the lane archive (used for demultiplexed lanes)

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

$Author: mg8 $

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Marina Gourtovaia

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
