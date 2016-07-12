package npg_tracking::glossary::composition;

use Moose;
use namespace::autoclean;
use MooseX::Storage;
use MooseX::StrictConstructor;
use List::MoreUtils qw/ bsearch/;
use Readonly;
use Carp;

with Storage( 'traits' => ['OnlyWhenBuilt'],
              'format' => '=npg_tracking::glossary::composition::serializable' );

our $VERSION = '0';

Readonly::Scalar my $DIGEST_TYPE => 'md5';

has 'components' => (
      isa       => 'ArrayRef[Object]',
      traits    => [ qw/Array/ ],
      is        => 'ro',
      required  => 1,
      handles   => {
          '_sort_components'  => 'sort_in_place',
          'num_components'    => 'count',
          'components_list'   => 'elements',
                   },
);

has '_checksum' => (
      isa       => 'Str',
      is        => 'ro',
      required  => 0,
      init_arg  => undef,
      writer    => '_set_checksum',
);

sub BUILD {
  my $self = shift;
  if (scalar @{$self->components} == 0) {
    croak 'Composition cannot be empty';
  }
  $self->_sort_components(sub { $_[0]->compare_serialized($_[1]) });
  $self->_set_checksum($self->digest($DIGEST_TYPE));
  return;
}

around 'freeze' => sub {
  my ($orig, $self, @args) = @_;
  my $frozen = $self->$orig;
  if ( $self->_checksum() && ($self->_checksum() ne
       $self->compute_digest($frozen, $DIGEST_TYPE)) ) {
    croak 'Composition has changed';
  }
  return $frozen;
};

sub find {
  my ($self, $c) = @_;
  return $self->find_in_sorted_array($c);
}

sub find_in_sorted_array {
  my ($self, $c, $a) = @_;
  $self->_test_component($c);
  $a ||= $self->components;
  my @found = bsearch { $_->compare_serialized($c) } @{$a};
  return @found ? $found[0] : undef;
}

sub _test_component {
  my ($self, $c) = @_;
  if ( !defined $c ) {
    croak 'Missing component';
  }
  if ( !(ref $c) || ref =~ /HASH|ARRAY/xms ) {
    croak q[Object is expected];
  }
  return 1;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

npg_tracking::glossary::composition

=head1 SYNOPSIS

  package my::package;
  use Moose;
  use namespace::autoclean;
  use npg_tracking::glossary::composition;

  has 'composition' => (
    is        => 'ro',
    required  => 1,
    isa       => 'npg_tracking::glossary::composition',
    handles   => {
      'composition_digest' => 'digest',
    }
  );
 
  __PACKAGE__->meta->make_immutable;
  1;
  
A class that uses its own attributes to build the composition,
see npg_tracking::glossary::composition::factory::attributes for details.

  package my::package;
  use Moose;
  use namespace::autoclean;
  with 'npg_tracking::glossary::composition::factory::attributes' =>
    => { component_class => 'my::component' };

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
    return $self->create_composition();
  }
 
  __PACKAGE__->meta->make_immutable;
  1;

=head1 DESCRIPTION

A base class for a collection of one or more entities (components).
See npg_tracking::glossary::composition::component for a generic component
interface and npg_tracking::glossary::composition::component::illumina
for Illumina sequencing specific implementation.

See npg_tracking::glossary::composition::factory and roles in
npg_tracking::glossary::composition::factory::* for factory methods to
generate the composition object.

A file with sequencing data can contain reads obtained in a single
sequencing run or in a number of runs. The composition describes the origin
of the data via components. The component binds together necessary and
sufficient metadata belonging to data originating from a single experiment
on a sample or library.

For example, for Illumina sequencing, data for a particular sample, which are
obtained in a single sequencing experiment, are inambiquously defined by run
or flowcell id, flowcell position and tag sequence or tag index. A sample
or library can be sequenced a number of times in different runs. 

Attempt Run_Id Lane_Id Tag_Index
1         3       2        56
2         7       7        56
3         9       1        56

The data then can be merged together into a single file. For auditing
purposes it is important to know the origin of the data, which is
given by a composition of three components, 3-2-56, 7-7-56 and 9-1-56,
a triplet per component.

Where the data originates from a single run, is can be described
by a composition containing a single component. Thus the data from attempt
1 in the above example are described by a one-componet composition 3-2-56.   

=head1 SUBROUTINES/METHODS

=head2 BUILD

An extension for the constructor method. Checks that the composition is
not empty (error for an empty composition) and sorts the composition
thus ensuring that the order the components were given to the composition
factory does not matter.

=head2 components

A reference to a non-empty array of component objects, see
npg_tracking::glossary::composition::component interface.
Do not change this array directly.

=head2 components_list

A list of component objects.

=head2 num_components

Returns number of components.

  print 'Number of components ' . $composition->num_components();

=head2 find

Finds and returns a component that is equal to the argument component.
The comparison is based on the compare_serialized method of the
npg_tracking::glossary::composition::component object.

  my $found = $composition->find($component);

Undefined value is returned if nothing was found.

=head2 find_in_sorted_array

As find(), but can take optionally a sorted array to perform a search on.
  
  $composition->find_in_sorted_array($component);
  $composition->find_in_sorted_array($component, $array);

=head2 freeze

Returns a custom canonical (sorted) JSON serialization of the object.

Guaranteed to be the same for a set of components regardless of the
order the componets were added to the composition. Inherited from
npg_tracking::glossary::composition::serializable. Raises an error
if the internal signature of the object has changed since the object
was created.

  $composition->freeze();

=head2 freeze2rpt

Returns a serialization of the object to a string representation of
the rpt list. Components should at least implement id_run and
position methods/attributes, otherwise this method gives an error.
See npg_tracking::glossary::rpt.

Guaranteed to be the same for a set of components regardless of the
order the componets were added to the composition. Inherited from
npg_tracking::glossary::composition::serializable.

  $composition->freeze2rpt();

If the composition is empty, and empty string is returned.

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

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::Storage

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Readonly

=item Carp

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
