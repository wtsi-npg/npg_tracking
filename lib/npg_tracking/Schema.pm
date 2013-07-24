use utf8;
package npg_tracking::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use Moose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Q1r19LhirPv0eU8pL62qKQ

# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: mg8 $
# Created:       2010-04-08
# Last Modified: $Date: 2013-01-07 11:04:50 +0000 (Mon, 07 Jan 2013) $
# Id:            $Id: Schema.pm 16389 2013-01-07 11:04:50Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema.pm $

BEGIN {
  use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 16389 $ =~ /(\d+)/mxs; $r; };
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

Update with:

  (export PATH=/software/perl-5.14.2/bin/:$PATH; export PERL5LIB=/software/solexa/npg_cpan/lib/perl5/; /software/solexa/npg_cpan/bin/dbicdump  -o naming=current  -o rel_name_map='sub {my%h=%{shift@_};my$name=$h{name}; $name=~s/^id_//; return $name; }' -o debug=0 -o dump_directory=./lib -o skip_load_external=1 -o use_moose=1 -o components='[qw(InflateColumn::DateTime)]' npg_tracking::Schema "dbi:mysql:host=XXXXX;port=XXXX;dbname=npgt" "npgro" "" )

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





# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
