package npg_tracking::glossary::composition::factory::attributes;

use strict;
use warnings;
use MooseX::Role::Parameterized;
use Class::Load qw/load_class/;
use Carp;

use npg_tracking::glossary::composition::factory;

our $VERSION = '0';

parameter 'component_class' => (
        isa      => 'Str',
        required => 1,
);

role {
  my $param = shift;

  method 'create_component' => sub {
    my $self = shift;

    my $class = $param->component_class;
    load_class($class);

    my $h = {};
    for my $attr_obj ( $class->meta->get_all_attributes ) {
      my $attr = $attr_obj->name;
      if ($self->can($attr) && defined $self->$attr) {
        $h->{$attr} = $self->$attr;
      }
      if (!exists $h->{$attr} && $attr_obj->is_required()) {
        $h->{$attr} = undef;
      }
    }

    return $class->new($h);
  };

  method 'create_composition' => sub {
    my $self = shift;
    my $factory = npg_tracking::glossary::composition::factory->new();
    $factory->add_component($self->create_component());
    return $factory->create_composition();
  };
};

1;
__END__

=head1 NAME

npg_tracking::glossary::composition::factory::attributes

=head1 SYNOPSIS

  package my::component;
  use Moose;
  has 'attr_1' => (isa => 'Int', is => 'ro', required => 1,);
  has 'attr_2' => (isa => 'Str', is => 'ro', required => 1,);
  1;

  package my::composition;
  use Moose;
  with 'npg_tracking::glossary::composition::factory::attributes' =>
    => { component_class => 'my::component' };

  has 'attr_1' => (isa => 'Int', is => 'ro', required => 1,);
  has 'attr_2' => (isa => 'Str', is => 'ro', required => 0,);
  has 'composition' => (isa => ' npg_tracking::glossary::composition',
                        required => 0, lazy_build => 1,);
  sub _build_composition {
    my $self = shift;
    return $self->create_composition();
  }
  1;

  package main;
  use my::composition;
  my $c = my::composition->new(attr_1 => 2);
  $c->composition(); # error, cannot satisfy required constraint
                     # for attr_2 in my::component
  my $c = my::composition->new(attr_1 => 2, attr_1 => 'apple');
  $c->composition(); # ok
  

=head1 DESCRIPTION

A Moose role providing factory functionality for npg_tracking::glossary::composition::component
and npg_tracking::glossary::composition type objects. The type of the component to be used
should be set as the component_class parameter.

=head1 SUBROUTINES/METHODS

=head2 create_component

Inspects the attributes of the object and returns an instance of
class specified as the component_class parameter. Populates all
attributes of component class that are present and defined in the
class consuming this role. Scalar values are copied, data structures
and objects are copied by reference. No weak copy for objects.

If the class consuming this role does not have an attribute where
in the component it is required, undefined value is used.

=head2 create_composition

Inspects the attributes of the object and returns an instance of
npg_tracking::glossary::composition with a single component.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item MooseX::Role::Parameterized

=item Class::Load

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
