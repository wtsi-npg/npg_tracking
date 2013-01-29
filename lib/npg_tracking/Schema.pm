package npg_tracking::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.06001 @ 2010-05-13 15:58:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:MAz9khLxunElph1Ghec03g

# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: mg8 $
# Created:       2010-04-08
# Last Modified: $Date: 2013-01-07 11:04:50 +0000 (Mon, 07 Jan 2013) $
# Id:            $Id: Schema.pm 16389 2013-01-07 11:04:50Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema.pm $

BEGIN {
  use Moose;
  use MooseX::NonMoose;
  use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 16389 $ =~ /(\d+)/mxs; $r; };
  extends 'DBIx::Class::Schema';
}

with qw/npg_tracking::util::db_connect/;

1;

__END__

=head1 NAME

npg_tracking::Schema

=head1 VERSION

$LastChangedRevision: 16389 $

=head1 SYNOPSIS

=head1 DESCRIPTION

A Moose class for a DBIx schema with an ability to retrieve db cridentials
from a configuration file. Provides a schema object for a DBIx binding
for the npg tracking database.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose

=item MooseX::NonMoose

=item DBIx::Class::Schema

=item npg_tracking::util::db_connect

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David Jackson

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, David Jackson

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



