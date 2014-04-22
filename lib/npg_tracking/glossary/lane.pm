#############
# Created By: Marina Gourtovaia
# Created On: 23 April 2010

package npg_tracking::glossary::lane;

use Moose::Role;

our $VERSION = '0';

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

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

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
