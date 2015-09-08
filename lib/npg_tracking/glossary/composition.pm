package npg_tracking::glossary::composition;

use Moose;
use namespace::autoclean;
use MooseX::Storage;
use MooseX::StrictConstructor;
use Carp;
use List::MoreUtils qw/ any uniq /;

with Storage( 'traits' => ['OnlyWhenBuilt'],
              'format' => '=npg_tracking::glossary::composition::serializable' );

our $VERSION = '0';

has 'components' => (
      traits    => [ qw/Array/ ],
      is        => 'ro',
      isa       => 'ArrayRef[Object]',
      default   => sub { [] },
      handles   => {
          'add_component'     => 'push',
          'has_no_components' => 'is_empty',
          'sort_components'   => 'sort_in_place',
          'find_component'    => 'first',
          'num_components'    => 'count',
                   },
);

before 'add_component' => sub {
  my ($self, @components) = @_;

  if (!@components) {
    croak 'Nothing to add';
  }

  my @seen = ();
  foreach my $c ( @components ) {
    _test_attr($c);
    if ( any { !$c->compare_serialized($_) } @seen ) {
      croak sprintf 'Duplicate entry in arguments to add: ', $c->freeze();
    }
    if ($self->find($c)) {
      croak sprintf 'Cannot add component %s, already exists', $c->freeze();
    }
    push @seen, $c;
  }
};

before 'digest' => sub {
  my ($self, @args) = @_;
  if ($self->has_no_components) {
    croak 'Composition is empty, cannot compute digest';
  }
};

before 'freeze' => sub {
  my ($self, @args) = @_;
  $self->sort();
};

sub component_values4attr {
  my ($self, $attr) = @_;

  if (!$attr) {
    croak 'Attribute name is missing';
  }
  if ($self->has_no_components) {
    croak qq[Composition is empty, cannot compute values for $attr];
  }
  my @values = uniq grep { defined $_ }  map { $_->can($attr) ? $_->$attr : undef } @{$self->components()};
  return @values;
}

sub find {
  my ($self, $c) = @_;
  if ( !defined $c ) {
    croak 'Missing argument';
  }
  _test_attr($c);
  return $self->find_component( sub { !($c->compare_serialized($_)) } );
}

sub sort {##no critic (Subroutines::ProhibitBuiltinHomonyms)
  my $self = shift;
  $self->sort_components(sub { $_[0]->compare_serialized($_[1]) });
  return;
}

sub _test_attr {
  my $c = shift;
  if ( !(ref $c) || ref =~ /HASH|ARRAY/xms ) {
    croak q[Object is expected];
  }
  return;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_tracking::glossary::composition

=head1 SYNOPSIS

A simple derived class example.

  package my::package;
  use Moose;
  use namespace::autoclean;
  use npg_tracking::glossary::composition;

  has 'composition' => (
    is        => 'ro',
    isa       => 'npg_tracking::glossary::composition',
    default   => sub { npg_tracking::glossary::composition->new() },
    handles   => {
      'composition_digest' => 'digest',
    }
  );
 
  __PACKAGE__->meta->make_immutable;
  1;
  
A derived class that uses its own attributes to build the composition,
see npg_tracking::glossary::composition::factory for details.

  package my::package;
  use Moose;
  use namespace::autoclean;
  with qw( npg_tracking::glossary::composition::factory );

  has 'composition' => (
    is         => 'ro',
    isa        => 'npg_tracking::glossary::composition',
    lazy_build => 1,
    handles    => {
      'composition_digest' => 'digest',
    }
  );
  sub _build_composition {
    my $self = shift;
    return $self->create_sequence_composition();
  }
 
  __PACKAGE__->meta->make_immutable;
  1;

=head1 DESCRIPTION

Definition for a composition of multiple entities (lanes and/or lanelets).

=head1 SUBROUTINES/METHODS

=head2 components

An array reference of component objects, empty by default. The
order of the object in the array is not necessary the order the objects
are added in, ie this array cannot be treated as a queue.

=head2 add_component

Appends a single component object or a list of component objects
to the end of the components array.

  $composition->add($component);
  $composition->add((($component1, $component2));

Gives an error if a list of components contains duplicates or if any of
the argument components already exists in the components array.

=head2 has_no_components

Returns true if the components array is empty, false otherwise.

  if ($composition->has_no_components()) {
    print 'No components';
  }

=head2 num_components

Returns number of components.

  print 'Number of components ' . $composition->num_components();

=head2 find

Finds and returns a component that is equal to the argument component.
The comparison is based on the compare_serialized method of the
npg_tracking::glossary::composition::component object.

  my $found = $composition->find($component);

=head2 sort

Sorts components array in place. The comparison is based on the
compare_serialized method of the npg_tracking::glossary::composition::component
object.

  $composition->sort();

=head2 freeze

Returns a custom canonical (sorted) JSON serialization of the object.
Guaranteed to be the same for a set of components regardless of the
order the componets were added to the composition. Inherited from
npg_tracking::glossary::composition::serializable.

  $composition->freeze();

=head2 thaw

Given a JSON string representing an object, returns an instance of the
object.

  my $composition = npg_tracking::glossary::composition->thaw($json_string);

=head2 digest

Computes a unique signature for the composition as defined by the
digest method in npg_tracking::glossary::composition::serializable.
Gives an error if the components array is empty.

  $composition->digest();      # sha256_hex digest
  $composition->digest('md5'); # md5 digest

=head2 component_values4attr

Returns a list of distinct true attribute values of the components. Takes
the attribute name as input. An empty list is returned if none of the
components has this value defined defined. Error if the composition is empty. 

  my @subsets = $composition->component_values4attr('subset');

The caller can enforce that the composition is homogeneous in respect of
the attribute value.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::Storage

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Carp

=item List::MoreUtils

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL

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
