package st::api::lims::ml_warehouse::driver;

use Moose;
use Carp;

use st::api::lims;
use npg_tracking::util::types;
use WTSI::DNAP::Warehouse::Schema;

with qw/  npg_tracking::glossary::lane
          npg_tracking::glossary::tag
          npg_tracking::glossary::flowcell /;

our $VERSION = '0';

=head1 NAME

st::api::lims::ml_warehouse::driver

=head1 SYNOPSIS

=head1 DESCRIPTION

Parent class for a family of ml_warehouse drivers for st::api::lims class
for Illumina platform data.

=head1 SUBROUTINES/METHODS

=head2 flowcell_barcode

=head2 id_flowcell_lims

=head2 id_run

id_run, optional attribute.

=cut

has 'id_run' => ( isa        => 'Maybe[NpgTrackingRunId]',
                  is         => 'ro',
                  required   => 0,
                  lazy_build => 1,
);
sub _build_id_run {
  my $self = shift;
  carp join q( ), 'No id_run set yet',
    ($self->has_flowcell_barcode ?
    ('flowcell_barcode: ' . ($self->flowcell_barcode // q{"Value not defined"})) : ()),
    ($self->has_id_flowcell_lims ?
    ('id_flowcell_lims: ' . ($self->id_flowcell_lims // q{"Value not defined"})) : ());
  return;
}

=head2 position

Position, optional attribute.

=cut

has '+position' => ( required => 0, );

=head2 tag_index

Tag index, optional attribute

=head2 mlwh_schema

WTSI::DNAP::Warehouse::Schema connection

=cut

has 'mlwh_schema' => ( isa        => 'WTSI::DNAP::Warehouse::Schema',
                       is         => 'ro',
                       lazy_build => 1,
);

=head2 is_pool

Read-only boolean attribute, not possible to set from the constructor.

=cut

has 'is_pool' => ( isa        => 'Bool',
                   is         => 'ro',
                   init_arg   => undef,
                   lazy_build => 1,
);

=head2 spiked_phix_tag_index

Read-only integer attribute, not possible to set from the constructor.
Defined for a lane and all tags, including tag zero.

=cut

has 'spiked_phix_tag_index' => ( isa        => 'Maybe[NpgTrackingTagIndex]',
                                 is         => 'ro',
                                 init_arg   => undef,
                                 lazy_build => 1,
);

=head2 spti_from_rows

Helper method to retrieve spiked_phix_tag_index value from DBIx rows.
Arguments: an array of DBIx rows. Returns spiked sample tag index or
undefined if the argument array was empty.

=cut

sub spti_from_rows {
  my ($self, $rows) = @_;
  my $tag_index;
  my $row = $rows->[0];
  if ($row) {
    croak q[Multiple spike definitions] if @{$rows} > 1;
    $tag_index = $row->tag_index;
    if (!$tag_index) {
      croak q[Tag index for the spike is missing];
    }
  }
  return $tag_index;
}

sub _to_delegate {
  my $package = 'WTSI::DNAP::Warehouse::Schema::Result::IseqFlowcell';
  return [ grep { $package->can($_) }
           st::api::lims->driver_method_list_short(__PACKAGE__->meta->get_attribute_list) ];
}

=head2 dbix_row

Underlying database record, might be undefined.
This attribute has no public accessors.
A lazy builder _build_dbix_row has to be provided by a child class.

=cut

has 'dbix_row' => ( isa        => 'Maybe[WTSI::DNAP::Warehouse::Schema::Result::IseqFlowcell]',
                    is         => 'bare',
                    init_arg   => undef,
                    lazy_build => 1,
                    handles    => _to_delegate(),
                    reader     => '_get_dbix_row',
                    builder    => '_build_dbix_row',
);

foreach my $method (_to_delegate()) {
  around $method => sub {
    my ($orig, $self) = @_;
    return $self->_get_dbix_row() ? $self->$orig() : undef;
  };
}

=head2 count

Number of underlying records used for evaluating this object

=cut

sub count {
  return 0;
}

=head2 children

=cut

sub children {
  return ();
}

=head2 copy_init_attrs

Returns a hash reference with values of core attributes of this object.
The following attributes are considered: id_flowcell_lims, flowcell_barcode, id_run.

=cut

sub copy_init_attrs {
  my $self = shift;
  my $init = {};
  foreach my $init_attr ( qw/id_flowcell_lims flowcell_barcode id_run/) {
    my $pred = "has_$init_attr";
    if ($self->$pred) {
      $init->{$init_attr} = $self->$init_attr;
    }
  }
  return $init;
}

=head2 children_attrs

Returns a sorted array of either tag indexes or positions.
Arguments: an array of children DBIx row objects,
           attribute name (tag_index or position).
Errors if the attribute value is not defined in one of the
rows, so should not be called call on non-pool object with tag_index
attribute name.

=cut

sub children_attrs {
  my ($self, $rows, $attr_name) = @_;

  if ( !$attr_name || $attr_name !~ /tag_index|position/smx ) {
    croak 'Attribute name should be defined as either tag_index or position';
  }

  my %attrs = ();
  foreach my $row (@{$rows}) {
    if (defined $row->$attr_name) {
      $attrs{$row->$attr_name} = 1;
    } else { # Unlikely to happen for a position attribute since it's not
             # nullable in the database.
      croak "$attr_name should be defined for a child of " . $self->to_string();
    }
  }

  return [ (sort {$a <=> $b} keys %attrs) ];
}

=head2 to_string

Human friendly description of the object

=cut

sub to_string {
  my $self = shift;
  my $s = ref $self;
  foreach my $attr (qw(flowcell_barcode id_flowcell_lims position tag_index)) {
    if (defined $self->$attr) {
      $s .= qq[ $attr ] . $self->$attr . q[,];
    }
  }
  $s =~ s/,\Z/\./xms;
  return $s;
}

no Moose;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item npg_tracking::util::types

=item npg_tracking::glossary::lane

=item npg_tracking::glossary::tag

=item npg_tracking::glossary::flowcell

=item st::api::lims

=item WTSI::DNAP::Warehouse::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017, 2023 Genome Research Ltd.

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
