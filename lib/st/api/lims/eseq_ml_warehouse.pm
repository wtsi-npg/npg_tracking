package st::api::lims::eseq_ml_warehouse;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;
use Readonly;

extends 'st::api::lims::ml_warehouse::generic_driver';

our $VERSION = '0';

Readonly::Scalar my $LIMS_RESULT_CLASS =>
  'WTSI::DNAP::Warehouse::Schema::Result::EseqFlowcell';
Readonly::Array my @DELEGATED_METHODS =>
  @{__PACKAGE__->delegated_methods($LIMS_RESULT_CLASS)};

=head1 NAME

st::api::lims::eseq_ml_warehouse

=head1 SYNOPSIS

 $l = st::api::lims->new(
   id_run => 51000,
   position => 1,
   driver_type =>eseq_ml_warehouse'
 );
 for my $p ($l->children) {
    print 'Tag index ' . $p->tag_index;
 }

=head1 DESCRIPTION

Implementation of the C<eseq_ml_warehouse> driver type for C<st::api::lims>
class, the driver for Elembio data.

We have runs where the same sample in the same lane is represented by multiple
tag sequences. This is a common scenario for Elembio own controls. Since data
for the same sample is bundled together by bases2fastq, in mlwh we assign the
same tag index to these libraries. This implementation presents all these
libraries as a single C<st::api::lims> object. A plex-level C<st::api::lims>
object can only have one tag sequence. So far in cases like this mostly for
display purposes we sorted the tag sequences alphabethically and used the first
one from the list. The same approach is used here. It might have limitations
and therefore in future might need a review and an adjustment. At the time of
writing (March 2026) there is no clear driver to represent such libraries
individually.

=head1 SUBROUTINES/METHODS

=head2 to_string

Human-friendly description of the object.
Inherited from parent C<st::api::lims::ml_warehouse::generic_driver>.

=head2 id_run

NPG tracking run id, required.
Inherited from parent C<st::api::lims::ml_warehouse::generic_driver>.

=head2 position

Position, optional attribute.
Inherited from parent C<st::api::lims::ml_warehouse::generic_driver>.

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

Number of children.

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

  if (!$self->tag_index) { # This object is for either a run, or lane, or tag 0.

    my $package_name = ref $self;
    my $init = $self->copy_init_attrs();

    if ($self->position) {
      my @tag_indices =
        map { $_->tag_index }
        $self->mlwh_schema->resultset('EseqProductMetric')->search(
          {
            id_run => $self->id_run,
            lane => $self->position,
            tag_index => {q[!=], 0},
          },
          {
            distinct => 1,
            columns  => 'tag_index',
            order_by => 'tag_index'
          }
        )->all;

      @tag_indices or croak 'No product records for ' . $self->to_string();
      @children = map { $package_name->new(%{$init}, tag_index => $_) }
                  @tag_indices;
    } else {
      my @positions =
        map { $_->lane }
        $self->mlwh_schema->resultset('EseqProductMetric')->search(
          {
            id_run => $self->id_run,
          },
          {
            distinct => 1,
            columns  => 'lane',
            order_by => 'lane'
          }
        )->all;

      @positions or croak croak 'No product records for ' . $self->to_string();
      @children = map { $package_name->new(%{$init}, position => $_) }
                  @positions;
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

NPG tag index for Elembio sequencing control.

Read-only integer attribute, not possible to set from the constructor.
Inherited from parent C<st::api::lims:::ml_warehouse::generic_driver>.

This class implements a builder method for the attribute.
The value is expected to be defined for a lane and tags.

Multiple sequencing control records might exist under the same C<tag_index>,
this is not an error. Multiple sequencing controls with different C<tag_index>
value is an error.

=cut

sub _build_spiked_phix_tag_index {
  my $self = shift;

  my $row;
  if ($self->position) {
    my $rs = $self->mlwh_schema->resultset('EseqProductMetric')->search(
      {
        id_run => $self->id_run,
        lane => $self->position,
        is_sequencing_control => 1
      },
      {
        columns => 'tag_index',
        group_by => 'tag_index'
      }
    );
    $row = $rs->next;
    $row && $rs->next && croak 'Sequencing control with different tag indexes';
  }
  return $row ? $row->tag_index : undef;
}

#####
# eseq_product_metrics table row for this entity. The attribute is defined
# for plex-level non-tag zero objects only. Error if no database records
# are found.
#
has '_product_row' => (
  isa        => 'Maybe[WTSI::DNAP::Warehouse::Schema::Result::EseqProductMetric]',
  is         => 'bare',
  init_arg   => undef,
  lazy_build => 1,
  reader     => '_get_product_row',
);

sub _build__product_row {
  my $self = shift;

  # Note that where multiple rows have the same tag index, the first retrieved
  # row is returned. For consistency teh rows are ordered by tag sequence. 
  if ($self->tag_index) {
    $self->position or croak 'Position should be defined';
    my $rs = $self->mlwh_schema->resultset('EseqProductMetric')->search(
      {
        id_run => $self->id_run,
        lane => $self->position,
        tag_index => $self->tag_index
      },
      {
        order_by => [qw/tag_sequence tag2_sequence/]
      }
    );
    my $row = $rs->next;
    $row or croak 'No database record retrieved for ' . $self->to_string();
    return $row;
  }

  return;
}

#####
# useq_wafer table row for this entity. Is undefined if the value of
# _product_row is undefined. Handles a number of standard st::api::lims
# driver methods for LIMS data retrieval. See IseqFlowcell Result class for
# implementation details of these methods.
#
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
  return $row ? $row->eseq_flowcell : undef;
}

#####
# Delegated methods are modified to ensure that the absence of a link from the
# product row to the eseq_flowcell row does not cause a run-time failure. 
#
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

=item st::api::lims

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
