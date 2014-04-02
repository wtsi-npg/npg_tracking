#########
# Author:        jo3
# Maintainer:    $Author: jo3 $
# Created:       2010-04-28
# Last Modified: $Date: 2010-10-21 17:20:43 +0100 (Thu, 21 Oct 2010) $
# Id:            $Id: Username.pm 11439 2010-10-21 16:20:43Z jo3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/Monitor/Roles/Username.pm $

package Monitor::Roles::Username;

use Moose::Role;

our $VERSION = '0';

Readonly::Scalar my $USERNAME => 'pipeline';

has _username => (
    reader     => 'username',
    is         => 'ro',
    isa        => 'Str',
    default    => $USERNAME,
    documentation => 'The username to attach to database updates',
);


1;

__END__


=head1 NAME

Monitor::Roles::Username - username to use when writing run statuses etc to
the npg tracking database.

=head1 VERSION



=head1 SYNOPSIS

    C<<use Moose;
       with 'Monitor::Roles::Username';>>

=head1 DESCRIPTION

Right now all it does is return a username. Potentionally SSO stuff could be
added here.

=head1 SUBROUTINES/METHODS


=head1 CONFIGURATION AND ENVIRONMENT


=head1 INCOMPATIBILITIES


=head1 BUGS AND LIMITATIONS


=head1 AUTHOR

John O'Brien, E<lt>jo3@sanger.ac.ukE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (C) 2010 GRL, by John O'Brien

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
