package st::api::lims::ml_warehouse_fc_cache;

use Moose;
use MooseX::StrictConstructor;
use Carp;
use List::MoreUtils qw(any uniq);

use WTSI::DNAP::Warehouse::Schema;
use WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell;

extends qw/ st::api::lims::ml_warehouse::driver /;

our $VERSION = '0';

=head1 NAME

st::api::lims::ml_warehouse_fc_cache

=head1 SYNOPSIS

=head1 DESCRIPTION

Implementation of the ml_warehouse driver for st::api::lims
class. LIMs data are retrieved from the warehouse defined
in WTSI::DNAP::Warehouse::Schema. Pulls and caches all info
for a run no matter if looking at lane or plex.

=head1 SUBROUTINES/METHODS

=head2 BUILD

sanity checks on construction

=cut

sub BUILD {
  my($self)=@_;
  my@r= $self->position ? $self->_position_resultset_rows : $self->_run_resultset_rows;
  if ($self->tag_index) {
    @r = grep{defined $_->tag_index and $_->tag_index == $self->tag_index}@r;
  }
  croak 'No record retrieved for ' . $self->to_string if not @r;
  return;
};

=head2 to_string

Human friendly description of the object

=head2 flowcell_barcode

=head2 id_flowcell_lims

=head2 id_run

id_run, optional attribute.

=cut

override '_build_id_run' => sub {
  my $self = shift;

  my @ids = uniq grep {defined} map {$_->id_run}
       map {$_->iseq_product_metrics} $self->_run_resultset_rows;
  if(@ids) {
    my $id_run = pop @ids;
    croak 'Found more than one id_run' if @ids;
    return $id_run;
  }

  return super();
};

=head2 position

Position, optional attribute.

=head2 tag_index

Tag index, optional attribute

=head2 mlwh_schema

WTSI::DNAP::Warehouse::Schema connection

=cut

sub _build_mlwh_schema {
  my $self = shift;
  return WTSI::DNAP::Warehouse::Schema->connect();
}


has '_run_resultset_rows_cache' =>
                         ( isa        => 'ArrayRef',
                           traits     => ['Array'],
                           is         => 'ro',
                           lazy_build => 1,
                           handles    => { _run_resultset_rows => 'elements'},
);
sub _build__run_resultset_rows_cache {
  my $self = shift;
  my $q = {};
  if ($self->has_id_flowcell_lims) { $q->{id_flowcell_lims}=$self->id_flowcell_lims; }
  elsif ($self->has_id_run) { $q->{id_run}=$self->id_run; }
  elsif ($self->has_flowcell_barcode) { $q->{flowcell_barcode}=$self->flowcell_barcode; }
  croak 'Either id_flowcell_lims, flowcell_barcode or id_run should be defined' if not keys %{$q};
  return [$self->mlwh_schema->resultset('IseqFlowcell')
    ->search($q,{prefetch =>[qw(sample study iseq_product_metrics)]})->all];
}

has '_position_resultset_rows_cache' =>
                         ( isa        => 'ArrayRef',
                           traits     => ['Array'],
                           is         => 'ro',
                           lazy_build => 1,
                           handles    => { _position_resultset_rows => 'elements'},
);
sub _build__position_resultset_rows_cache {
  my $self=shift;
  my $p = $self->position;
  croak 'Trying to access position or tag level info without a position' if not $p;
  return [grep {$p == $_->position} $self->_run_resultset_rows];
}

=head2 count

Number of underlying records used for evaluating this object

=cut

override 'count' => sub {
  my$self=shift;
  my@r = $self->position ? $self->_position_resultset_rows : $self->_run_resultset_rows;
  return scalar @r;
};

=head2 children

=cut

override 'children' => sub {
  my $self = shift;

  my @children = ();

  if (!$self->tag_index) {

    my $package_name = ref $self;
    my $init = $self->copy_init_attrs();
    $init->{'_run_resultset_rows_cache'} = $self->_run_resultset_rows_cache;

    if ($self->position) {
      if ($self->is_pool) {
        $init->{'position'}    = $self->position;
        my $attrs = $self->children_attrs(
          $self->_position_resultset_rows_cache, 'tag_index');
        foreach my $tag_index (@{$attrs}) {
          $init->{'tag_index'} = $tag_index;
          push @children, $package_name->new($init);
        }
      }
    } else {
      my $attrs = $self->children_attrs(
        $self->_run_resultset_rows_cache, 'position');
      foreach my $position (@{$attrs}) {
        $init->{'position'}    = $position;
        push @children, $package_name->new($init);
      }
    }
  }

  return @children;
};

=head2 is_pool

Read-only boolean attribute, not possible to set from the constructor.

=cut

sub _build_is_pool {
  my $self = shift;
  my $indexed_lib_type = $WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell::INDEXED_LIBRARY;
  if ( $self->position && !$self->tag_index ) {
    return 1 if any {
      $_->entity_type eq $indexed_lib_type
    } $self->_position_resultset_rows;
  }
  return 0;
}

=head2 spiked_phix_tag_index

Read-only integer attribute, not possible to set from the constructor.
Defined for a lane and all tags, including tag zero.

=cut

sub _build_spiked_phix_tag_index {
  my $self = shift;
  if ($self->position) {
    my $spike_type = $WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell::INDEXED_LIBRARY_SPIKE;
    return $self->spti_from_rows(
      [grep {$_->entity_type eq $spike_type} $self->_position_resultset_rows]);
  }
  return;
}

=head2 qc_state

Same logic as found in WTSI::DNAP::Warehouse::Schema::Result::IseqFlowcell

=cut

override 'qc_state' => sub {
  my $self = shift;
  if( $self->position ){
    my @r = $self->_position_resultset_rows;
    my $t = $self->tag_index;
    if( defined $t ){
      @r = grep {$_->tag_index and $_->tag_index == $t} @r;
    } else {
      my $spike_type = $WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell::INDEXED_LIBRARY_SPIKE;
      @r = grep {$_->entity_type ne $spike_type} @r;
    }
    @r = grep {defined} map {$_->qc} map {$_->iseq_product_metrics} @r;
    return shift @r if @r==1;
  }
  return;
};

=head2 dbix_row

Underlying database record, might be undefined.

=cut

sub _build_dbix_row {
  my $self = shift;

  if ($self->position) {
    if (!$self->is_pool) {
      my @rs;
      if ($self->tag_index) {
        @rs = grep{$_->tag_index == $self->tag_index} $self->_position_resultset_rows;
      } else {
        my @lib_types = ($WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell::NON_INDEXED_LIBRARY,
                         $WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell::CONTROL_LANE);
        @rs = grep {my $et=$_->entity_type; any {$_ eq $et} @lib_types} $self->_position_resultset_rows;
      }
      if( my $row = shift @rs ) {
        croak 'Multiple entities ('.(scalar @rs).' excess) for ' . $self->to_string if @rs;
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

David Jackson E<lt>david.jackson@sanger.ac.ukE<gt>

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
