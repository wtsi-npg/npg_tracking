#########
# Author:        jo3
# Created:       2010-04-28

package Monitor::Roles::Schema;

use Moose::Role;
use npg_tracking::Schema;

our $VERSION = '0';

has _schema => (
    reader     => 'schema',
    is         => 'ro',
    isa        => 'npg_tracking::Schema',
    lazy_build => 1,
);

sub _build__schema {
    my ($self) = @_;
    return npg_tracking::Schema->connect();
}

1;


__END__


=head1 NAME

Monitor::Roles::Schema - provide the DBIx npg_tracking schema.

=head1 VERSION

=head1 SYNOPSIS

    C<<use Moose;
       with 'Monitor::Roles::Schema';>>

=head1 DESCRIPTION

Create a DBIx schema.

=head1 SUBROUTINES/METHODS


=head1 CONFIGURATION AND ENVIRONMENT

Will decide whether to use live or dev on the basis of, in order, a 'dev'
constructor attribute, $ENV{dev}, or the default value 'live';

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
