package npg_tracking::glossary::composition::factory;

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;
use List::MoreUtils qw/ any /;
use Carp;

use npg_tracking::glossary::composition;

our $VERSION = '0';

has '_components' => (
      isa       => 'ArrayRef[Object]',
      traits    => [ qw/Array/ ],
      is        => 'ro',
      required  => 0,
      init_arg => undef,
      default   => sub { [] },
      handles   => {
          'add_component'     => 'push',
                   },
);

has '_closed' => (
      isa       => 'Bool',
      is        => 'ro',
      default   => 0,
      reader    => 'is_closed',
      writer    => '_set_closed',
);

sub _error_if_closed {
  my $self = shift;
  if ($self->_closed()) {
    croak 'Factory closed';
  }
  return;
}

before 'add_component' => sub {
  my ($self, @components) = @_;

  $self->_error_if_closed();
  if (!@components) {
    croak 'Nothing to add';
  }

  my @seen = ();
  foreach my $c ( @components ) {
    if ( any { !$c->compare_serialized($_) } @seen ) {
      croak sprintf 'Duplicate entry in arguments to add: %s', $c->freeze();
    }
    if (npg_tracking::glossary::composition->find_in_sorted_array($c, $self->_components)) {
      croak sprintf 'Cannot add component %s, already exists', $c->freeze();
    }
    push @seen, $c;
  }
};

sub create_composition {
  my $self = shift;
  $self->_error_if_closed();
  $self->_set_closed(1);
  return npg_tracking::glossary::composition->new(
    components => $self->_components;
  );
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_tracking::glossary::composition::factory

=head1 SYNOPSIS

  package my::component;
  use Moose;
  has 'attr_1' => (isa => 'Int', is => 'ro', required => 1,);
  has 'attr_2' => (isa => 'Str', is => 'ro', required => 1,);
  1;

  package my::composition;
  use Moose;
  use npg_tracking::glossary::composition::factory;

  my $factory = npg_tracking::glossary::composition::factory->new();
  $factory->add_component(my::component->new(attr_1 => 1, attr_2 => 'a'));
  $factory->add_component(my::component->new(attr_1 => 2, attr_2 => 'b'));
  my $composition = $factory->create_composition();

=head1 DESCRIPTION

Generic factory functionality for npg_tracking::glossary::composition type objects.

=head1 SUBROUTINES/METHODS

=head2 add_component

Stores a single component object or a list of component objects
inside the factory.

  $factory->add($component);
  $factory->add((($component1, $component2));

Gives an error if a list of components contains duplicates or if any of
the argument components have been already given to this factory.

Cannot be called after the create_composition() method has been called;

=cut

=head2 create_composition

Returns a composition containing all components added to the factory.
Can only be called once. The order of the objects in the array is not necessary
the same as the order the objects were added to the factory.

  $factory->create_composition();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item MooseX::StrictConstructor

=item Carp

=item List::MoreUtils

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL

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
