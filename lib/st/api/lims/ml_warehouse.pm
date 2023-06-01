package st::api::lims::ml_warehouse;

use Moose;
use MooseX::StrictConstructor;
use Carp;
use WTSI::DNAP::Warehouse::Schema;

extends qw/ st::api::lims::ml_warehouse::driver /;

our $VERSION = '0';

=head1 NAME

st::api::lims::ml_warehouse

=head1 SYNOPSIS

=head1 DESCRIPTION

Implementation of the ml_warehouse driver for st::api::lims
class. LIMs data are retrieved from the warehouse defined
in WTSI::DNAP::Warehouse::Schema.

=head1 SUBROUTINES/METHODS

=head2 BUILD

sanity checks on construction

=cut

sub BUILD {
  my ($self) = @_;
  # call query_resultset here to get its sanity checks on construction
  $self->query_resultset;
  return;
}

=head2 to_string

Human friendly description of the object

=head2 flowcell_barcode

=head2 id_flowcell_lims

=head2 id_run

id_run, optional attribute.

=cut

override '_build_id_run' => sub {
  my $self = shift;

  if (not $self->has_flowcell_barcode and not $self->has_id_flowcell_lims) {
    croak 'Require flowcell_barcode or id_flowcell_lims to try to find id_run';
  }
  my%search;
  if($self->has_flowcell_barcode){
    $search{'flowcell_barcode'} = $self->flowcell_barcode;
  }
  if($self->has_id_flowcell_lims){
    $search{'id_flowcell_lims'} = $self->id_flowcell_lims;
  }
  my$id_run_rs=$self->iseq_flowcell->related_resultset('iseq_product_metrics')
    ->search(\%search,{'columns'=>[qw(id_run)], 'distinct'=>1});
  if( my$id_run_record = $id_run_rs->next() ){
    croak 'Found more than one id_run' if($id_run_rs->next());
    return $id_run_record->id_run;
  }

  return super();
};

=head2 position

Position, optional attribute.

=head2 tag_index

Tag index, optional attribute

=head2 iseq_flowcell

DBIx result set for the iseq_flowcell table

=cut
has 'iseq_flowcell' =>   ( isa             => 'DBIx::Class::ResultSet',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
);
sub _build_iseq_flowcell {
  my $self = shift;
  return $self->mlwh_schema->resultset('IseqFlowcell');
}

#######
# This role requires iseq_flowcell, which is implemented as
# an attribute rather than as a method in this class, hence,
# according to Moose documentation, the need to consume the
# role after the attribute was defined.

with qw/ WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell /;

=head2 mlwh_schema

WTSI::DNAP::Warehouse::Schema connection

=cut

sub _build_mlwh_schema {
  my $self = shift;
  return  $self->has_query_resultset ?
    $self->query_resultset->result_source->schema :
    WTSI::DNAP::Warehouse::Schema->connect();
}

=head2 ensure_nonzero_query_resultset

Helper method for Moose "around" of query_resultset.

=cut
sub ensure_nonzero_query_resultset {
  my ($orig, $self) = @_;
  my $original = $self->$orig();
  my $rs = $original->search();
  if ($self->tag_index) {
    $rs = $rs->search({'me.tag_index' => $self->tag_index});
  }
  if (not $rs->first) {
    croak 'No record retrieved for ' . $self->to_string;
  }
  return $original;
};

=head2 query_resultset

Inherited from WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell.
Modified to raise error when no records for the LIMs object are
retrieved.

=cut

around 'query_resultset' => \&ensure_nonzero_query_resultset;

=head2 count

Number of underlying records used for evaluating this object

=cut

override 'count' => sub {
  my $self = shift;
  return $self->query_resultset->count();
};

=head2 children

=cut

has '_lchildren' => ( isa         => 'ArrayRef',
                      traits      => ['Array'],
                      is          => 'ro',
                      init_arg    => undef,
                      lazy_build  => 1,
                      clearer     => 'free_children',
                      handles     => { children => 'elements'},
);
sub _build__lchildren {
  my $self = shift;

  my @children = ();

  if (!$self->tag_index) { # This object is not for a plex

    my $package_name = ref $self;
    my $init = $self->copy_init_attrs();
    my $rs_array = [$self->query_resultset->all];

    if ($self->position) {
      if ($self->is_pool) {
        $init->{'query_resultset'} = $self->query_resultset;
        $init->{'position'}        = $self->position;
        foreach my $tag_index (@{$self->children_attrs($rs_array, 'tag_index')}) {
          $init->{'tag_index'} = $tag_index;
          push @children, $package_name->new($init);
        }
      }
    } else {
      foreach my $position (@{$self->children_attrs($rs_array, 'position')}) {
        $init->{'query_resultset'} = $self->query_resultset->search({'me.position' => $position});
        $init->{'position'}        = $position;
        push @children, $package_name->new($init);
      }
    }
  }

  $self->mlwh_schema(); # Cache db connection
  if (@children) {
    $self->free_query_resultset();
  }

  return \@children;
}

=head2 is_pool

Read-only boolean attribute, not possible to set from the constructor.

=cut

sub _build_is_pool {
  my $self = shift;
  if ( $self->position && !$self->tag_index ) {
    return $self->query_resultset->search( {entity_type =>
      $WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell::INDEXED_LIBRARY})->first ? 1 : 0;
  }
  return 0;
}

=head2 spiked_phix_tag_index

 Read-only integer attribute, not possible to set from the constructor.
 Defined for a lane and all tags, including tag zero

=cut

sub _build_spiked_phix_tag_index {
  my $self = shift;
  if ($self->position) {
    my $spike_type = $WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell::INDEXED_LIBRARY_SPIKE;
    return $self->spti_from_rows(
      [$self->query_resultset->search({entity_type => $spike_type})->all()]);
  }
  return;
}

=head2 dbix_row

Underlying database record, might be undefined.

=cut

sub _build_dbix_row {
  my $self = shift;

  if ($self->position) {
    if (!$self->is_pool) {
      my $rs;
      if ($self->tag_index) {
        $rs = $self->query_resultset->search({'me.tag_index' => $self->tag_index});
      } else {
        $rs = $self->query_resultset->search({entity_type => [
          $WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell::NON_INDEXED_LIBRARY,
          $WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell::CONTROL_LANE,
        ]});
      }
      if( my $row = $rs->next ) {
        croak 'Multiple entities for ' . $self->to_string if $rs->next;
        return $row;
      }
      croak 'No record for ' . $self->to_string;
    }
  }
  return;
}

no Moose;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item Carp

=item WTSI::DNAP::Warehouse::Schema

=item WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell

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
