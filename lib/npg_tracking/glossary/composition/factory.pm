package npg_tracking::glossary::composition::factory;

use Moose::Role;
use Carp;

use npg_tracking::glossary::composition::component;
use npg_tracking::glossary::composition;

our $VERSION = '0';

sub create_sequence_component {
  my $self = shift;

  my $class = 'npg_tracking::glossary::composition::component';
  my $h = {};
  for my $attr_obj ( $class->meta->get_all_attributes ) {
    my $attr = $attr_obj->name;
    $h->{$attr} = $self->can($attr) && defined $self->$attr ? $self->$attr : undef;
  }
  my $component;
  if ($h->{'id_run'} && $h->{'position'}) {
    $component = $class->new($h);
  } else {
    carp 'Both id_run and position attributes should be defined, ' .
         "cannot create $class object";
  }

  return $component;
}

sub create_sequence_composition {
  my $self = shift;
  my $c = $self->create_sequence_component();
  my $composition;
  if ($c) {
    $composition = npg_tracking::glossary::composition->new();
    $composition->add_component($c);
  }
  return $composition;
}

no Moose::Role;

1;
__END__

=head1 NAME

npg_tracking::glossary::composition::factory

=head1 SYNOPSIS

=head1 DESCRIPTION

A Moose role providing factory functionality for npg_tracking::glossary::composition::component
and npg_tracking::glossary::composition type objects.

=head1 SUBROUTINES/METHODS

=head2 create_sequence_component

Inspects the attributes of the object and returns an instance of
npg_tracking::glossary::composition::component type object. Returns undefined if the object
does not have either id_run or position attribute or either of these attrubutes are not set
to a true value.

=head2 create_sequence_composition

Inspects the attributes of the object and returns an instance of
npg_tracking::glossary::composition with a single component. Returns undefined if
create_sequence_component() returns undefined.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

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
