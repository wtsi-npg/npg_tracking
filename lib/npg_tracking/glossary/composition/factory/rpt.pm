package npg_tracking::glossary::composition::factory::rpt;

use strict;
use warnings;
use MooseX::Role::Parameterized;
use Class::Load qw/load_class/;

use npg_tracking::glossary::rpt;
use npg_tracking::glossary::composition::factory;

our $VERSION = '0';

requires 'rpt_list';

parameter 'component_class' => (
        isa      => 'Str',
        required => 1,
);

role {
  my $param = shift;

  method 'create_component' => sub {
    my ($self, $rpt) = @_;

    my $class = $param->component_class;
    load_class($class);
    my %attrs = map { $_->name() => 1} $class->meta->get_all_attributes();

    $rpt //= q[];
    my $init = npg_tracking::glossary::rpt->inflate_rpt($rpt);
    foreach my $key (keys %{$init}) {
      if (!$attrs{$key}) {
        delete $init->{$key};
      }
    }
    my $subset_attr_name = q[subset];
    if ($attrs{$subset_attr_name} && $self->can($subset_attr_name) && $self->$subset_attr_name) {
      $init->{$subset_attr_name} = $self->$subset_attr_name;
    }
    return $class->new($init);
  };

  method 'create_composition' => sub {
    my ($self) = @_;

    my $rpt_list = $self->rpt_list // q[];
    my $factory = npg_tracking::glossary::composition::factory->new();
    foreach my $rpt ( @{npg_tracking::glossary::rpt->split_rpts($rpt_list)} ) {
      $factory->add_component( $self->create_component($rpt) );
    }
    return $factory->create_composition();
  };
};

1;
__END__

=head1 NAME

npg_tracking::glossary::composition::factory::rpt

=head1 SYNOPSIS

  package my::composition;
  use Moose;

  has 'rpt_list'    => (isa => 'Str', is => 'ro', required => 1,);

  # The call to has which defines an attribute happens at runtime.
  # This means that you must define the attribute before consuming the role,
  # or else the role will not see the generated accessor.
  # See http://search.cpan.org/~ether/Moose-2.1604/lib/Moose/Manual/Roles.pod#Required_Attributes

  with 'npg_tracking::glossary::composition::factory::rpt' =>
       { 'component_class' =>
         'npg_tracking::glossary::composition::component::illumina' };

  has 'composition' => (isa        => 'npg_tracking::glossary::composition',
                        required   => 0,
                        lazy_build => 1,);
  sub _build_composition {
    my $self = shift;
    return $self->create_composition();
  }
  1;

  package main;
  use my::composition;
  my $c = my::composition->new(rpt_list => '3:4;3:4:7');
  my $composition = $c->composition();

=head1 DESCRIPTION

A Moose role providing factory functionality for
npg_tracking::glossary::composition::component and
npg_tracking::glossary::composition::component::illumina (or similar) type objects.
The type of the component to be used should be set as the component_class parameter.
Run:position:tag_index (rpt) strings and lists of strings are used as input.

Requires that the class consuming this role implements the rpt_list method
or attribute that returns a string representation of an rpt list. If this
class implements the subset attribute or method, which returns a true value,
and if the component class supports the subset attribute, the latter will
be set for all components in the composition.

The component class dooes not have to support all keys of the rpt hashes.

=head1 SUBROUTINES/METHODS

=head2 create_component

Returns an instance of a class specified by the component_class parameter. The
attributes of the component class are derived from the argument rpt string.
See inflate_rpt subroutine in npg_tracking::glossary::rpt.

  my $component = $obj->create_component('4:5:6');

=head2 create_composition

Returns an instance of npg_tracking::glossary::composition with potentially
multiple components of the type specified by the component_class parameter.
Uses a string representation of an rpt list as a source of components.
See inflate_rpts subroutine in npg_tracking::glossary::rpt.

  my $composition = $obj->create_composition();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item MooseX::Role::Parameterized

=item Class::Load

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
