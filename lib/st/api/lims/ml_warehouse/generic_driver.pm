package st::api::lims::ml_warehouse::generic_driver;

use Moose;
use namespace::autoclean;

use npg_tracking::util::types;

with qw/ npg_tracking::glossary::run
         npg_tracking::glossary::lane
         npg_tracking::glossary::tag /;

our $VERSION = '0';

=head1 NAME

st::api::lims::ml_warehouse::generic_driver

=head1 SYNOPSIS

=head1 DESCRIPTION

Parent class for a family of ml_warehouse drivers for
st::api::lims class. Defines common public methods and attributes.

=head1 SUBROUTINES/METHODS

=head2 id_run

NPG tracking run identifier, required.
Inherited from C<npg_tracking::glossary::run>.

=head2 position

Position, optional attribute.
Inherited from C<npg_tracking::glossary::lane>.

=cut

has '+position' => ( required => 0, );

=head2 tag_index

Tag index, optional attribute.
Inherited from C<npg_tracking::glossary::tag>.

=head2 mlwh_schema

C<WTSI::DNAP::Warehouse::Schema> connection. A child class should provide
a builder method C<_build_mlwh_schema>.

=cut

has 'mlwh_schema' => (
  isa        => 'WTSI::DNAP::Warehouse::Schema',
  is         => 'ro',
  lazy_build => 1,
);

=head2 is_pool

Read-only boolean attribute, not possible to set from the constructor.

=cut

has 'is_pool' => (
  isa      => 'Bool',
  is       => 'ro',
  init_arg => undef,
  lazy_build => 1,
);
sub _build_is_pool {
  my $self = shift;
  return $self->tag_index ? 0 : 1; # Tag zero, if implemented, is considered a pool.
}

=head2 spiked_phix_tag_index

NPG tag index of the sequencing control.
Read-only integer attribute, not possible to set from the constructor.
Defined for a lane and tags, including tag zero.

=cut

has 'spiked_phix_tag_index' => (
  isa        => 'Maybe[NpgTrackingPositiveInt]',
  is         => 'ro',
  init_arg   => undef,
  lazy_build => 1,
);

=head2 count

Number of underlying records used for evaluating this object.
A child class should provide a driver-specific implementation of this method.

=cut

sub count {
  return 0;
}

=head2 children

A list of child entities for this entity.
A child class should provide a driver-specific implementation of this method.

=cut

sub children {
  return ();
}

=head2 copy_init_attrs

Returns a hash reference with values of core attributes of this object.
The following attributes are copied if defined: C<id_run>, C<position>.
C<mlwh_schema> attribute is always copied (by reference), which might
trigger building this attribute.

=cut

sub copy_init_attrs {
  my $self = shift;
  my $init = {};
  foreach my $init_attr ( qw/id_run position/) {
    my $pred = "has_$init_attr";
    if ($self->$pred) {
      $init->{$init_attr} = $self->$init_attr;
    }
  }
  $init->{mlwh_schema} = $self->mlwh_schema();
  return $init;
}

=head2 to_string

Human friendly description of the object

=cut

sub to_string {
  my $self = shift;
  my $s = ref $self;
  foreach my $attr (qw(id_run position tag_index)) {
    if (defined $self->$attr) {
      $s .= qq[ $attr ] . $self->$attr . q[,];
    }
  }
  $s =~ s/,\Z/\./xms;
  return $s;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item npg_tracking::util::types

=item npg_tracking::glossary::lane

=item npg_tracking::glossary::tag

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2026 Genome Research Ltd.

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
