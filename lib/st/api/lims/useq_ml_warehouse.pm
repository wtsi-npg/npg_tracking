package st::api::lims::useq_ml_warehouse;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;
use Readonly;

use WTSI::DNAP::Warehouse::Schema;

extends 'st::api::lims::ml_warehouse::generic_driver';

our $VERSION = '0';

Readonly::Scalar my $LIMS_RESULT_CLASS =>
  'WTSI::DNAP::Warehouse::Schema::Result::UseqWafer';
Readonly::Array my @DELEGATED_METHODS =>
  @{__PACKAGE__->delegated_methods($LIMS_RESULT_CLASS)};

=head1 NAME

st::api::lims::useq_ml_warehouse

=head1 SYNOPSIS

 # Not defining position.
 my $l = st::api::lims->new(id_run => 51000, driver_type =>useq_ml_warehouse');
 for my $p ($l->children) {
    print 'Tag index ' . $p->tag_index;
 }

 # Explicitly defining position.
 $l = st::api::lims->new(
   id_run => 51000,
   position => 1,
   driver_type =>useq_ml_warehouse'
 );
 for my $p ($l->children) {
    print 'Tag index ' . $p->tag_index;
 }

=head1 DESCRIPTION

Implementation of the C<useq_ml_warehouse> driver type for C<st::api::lims>
class, the driver for Ultimagen data.

Since the concept of a lane is absent in Ultimagen sequencing, the lane-level
objects are not implemented. The children of the run level object are plexes,
ie target products. The control sample tag is not included into the list of
children.

Some NPG application will not work correctly if a position attribute is not
defined for a single component entity. The position attribute can be set to 1
via the constructor. No other position value is accepted.

=head1 SUBROUTINES/METHODS

=head2 to_string

Human-friendly description of the object.
Inherited from parent C<st::api::lims::ml_warehouse::generic_driver>.

=head2 id_run

NPG tracking run id, required.
Inherited from parent C<st::api::lims::ml_warehouse::generic_driver>.

=head2 position

Position, an optional attribute. The only allowed value is 1.
Inherited from parent C<st::api::lims::ml_warehouse::generic_driver>.

=cut

has '+position' => (
  trigger => \&_position_filter,
);
sub _position_filter {
  my ($self, $position) = @_;
  ($position == 1) or croak "Cannot assign $position to position. " .
    'The value can only be either 1 or undefined.';
  return;
}

=head2 tag_index

Tag index, optional attribute.
Inherited from parent C<st::api::lims::ml_warehouse::generic_driver>.

=head2 mlwh_schema

WTSI::DNAP::Warehouse::Schema connection.
Inherited from parent C<st::api::lims::ml_warehouse::generic_driver>.

=head2 is_pool

Inherited from parent C<st::api::lims::ml_warehouse::generic_driver>.

=head2 children

A list of child objects for this entity. Expected to be non-empty only for
a run-level or tag zero entity. Errors if no database product rows are found
for this run.

=head2 count

Number of child objects.

=cut

has '_lchildren' => (
  isa         => 'ArrayRef',
  traits      => ['Array'],
  is          => 'ro',
  init_arg    => undef,
  lazy_build  => 1,
  clearer     => 'free_children',
  handles     => { children => 'elements',
                   count    => 'count'},
);
sub _build__lchildren {
  my $self = shift;

  my @children = ();

  if (!$self->tag_index) { # This object is for a run or tag zero.

    my $package_name = ref $self;
    my $init = $self->copy_init_attrs();

    my @tag_indices =
      map { $_->tag_index}
      $self->mlwh_schema->resultset('UseqProductMetric')->search(
        {
          id_run => $self->id_run,
          tag_index => {q[!=], 0},
          is_sequencing_control => 0
        },
        {
          columns =>  'tag_index',
          order_by => 'tag_index'
        }
      )->all;

    @tag_indices or croak 'No product records for run ' . $self->id_run;

    foreach my $tag_index (@tag_indices) {
      $init->{'tag_index'} = $tag_index;
      push @children, $package_name->new($init);
    }
  }

  return \@children;
}


=head2 is_control

=cut

sub is_control {
  my $self = shift;
  my $row = $self->_get_product_row;
  return $row ? $row->is_sequencing_control : undef;
}

=head2 qc_state

QC pass or fail, can be defined as 0 or 1 for a product. 

=cut

sub qc_state {
  my $self = shift;
  my $row = $self->_get_product_row;
  return $row ? $row->qc : undef;
}

=head2 spiked_phix_tag_index

NPG tag index for Ultimagen sequencing control. The control is not necessary
a PhiX sample. The name of the attribute is retained to be compatible with the
code which was originally written for Illumina data.

Read-only integer attribute, not possible to set from the constructor.
Inherited from parent C<st::api::lims:::ml_warehouse::generic_driver>.

This class implements a builder method for the attribute.
The value is expected to be defined for a run and tags.
Errors if the run has multiple sequencing control records.

=cut

sub _build_spiked_phix_tag_index {
  my $self = shift;
  my $rs = $self->mlwh_schema->resultset('UseqProductMetric')
                ->search({id_run => $self->id_run, is_sequencing_control => 1});
  my $row = $rs->next;
  $row && $rs->next && croak 'Multiple rows for sequencing control';

  return $row ? $row->tag_index : undef;
}

#####
# useq_product_metrics table row for this entity. The attribute is defined
# for plex-level non-tag zero objects only. Both the absence of the database
# record and multiple records are error conditions.
has '_product_row' => (
  isa        => 'Maybe[WTSI::DNAP::Warehouse::Schema::Result::UseqProductMetric]',
  is         => 'bare',
  init_arg   => undef,
  lazy_build => 1,
  reader     => '_get_product_row',
);

sub _build__product_row {
  my $self = shift;

  if ($self->tag_index) {
    my $rs = $self->mlwh_schema->resultset('UseqProductMetric')
         ->search({id_run => $self->id_run, tag_index => $self->tag_index});
    my $row = $rs->next;
    $row or croak 'No database record retrieved for ' . $self->to_string;
    croak 'Multiple database records for ' . $self->to_string if $rs->next;
    return $row;
  }

  return;
}

#####
# useq_wafer table row for this entity. Is undefined if the value of
# _product_row is undefined. Handles a number of st::api::lims standard
# driver methods for LIMS data retrieval. See details of how these methods
# are implemented in UseqWafer Result class.
has '_lims_row' => (
  isa        => "Maybe[$LIMS_RESULT_CLASS]",
  is         => 'bare',
  init_arg   => undef,
  lazy_build => 1,
  handles    => \@DELEGATED_METHODS,
  reader     => '_get_lims_row',
);

sub _build__lims_row {
  my $self = shift;
  my $row = $self->_get_product_row();
  return $row ? $row->useq_wafer : undef;
}

#####
# Delegated methods are modified to ensure that the absence of a link from the
# product row to the useq_wafer row does not lead to a run-time failure. 
foreach my $method (@DELEGATED_METHODS) {
  around $method => sub {
    my ($orig, $self) = @_;
    return $self->_get_lims_row() ? $self->$orig() : undef;
  };
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item Carp

=item namespace::autoclean

=item Readonly

=item WTSI::DNAP::Warehouse::Schema

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
