#############
# Created By: ajb
# Created On: 2011-01-07

package npg::email::roles::instrument;
use strict;
use warnings;
use Moose::Role;

our $VERSION = '0';

requires qw{schema_connection};

=head1 NAME

npg::email::roles::instrument

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

Provides methods which are specific to instrument based events (like status changes and annotating)

requires a schema_connection method to be provided

=head1 SUBROUTINES/METHODS

=head2 get_instrument

Returns an instrument resultset object based on the instrument name provided

=cut

has q{get_instrument} => ( is => q{ro}, init_arg => undef, lazy_build => 1 );

sub _build_get_instrument {
  my ($self, $id_instrument) = @_;
  $id_instrument ||= $self->id_instrument();
  return $self->schema_connection()->resultset(q{Instrument})->find( {
    id_instrument => $id_instrument,
  } );
}

=head2 name

Returns the instrument name out of the database

=cut

has q{name} => (
  isa => q{Str},
  is  => q{ro},
  lazy_build => 1,
);

sub _build_name {
  my ( $self ) = @_;
  return $self->get_instrument()->name();
}

=head2 id_instrument

returns the instrument id from the entity, or stores it on construction

=cut

has id_instrument => (
  is         => 'ro',
  isa        => 'Int',
  lazy_build => 1,
);

sub _build_id_instrument {
  my ($self) = @_;
  return $self->entity->id_instrument();
}

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item English -no_match_vars

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL, by Andy Brown (ajb@sanger.ac.uk)

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
