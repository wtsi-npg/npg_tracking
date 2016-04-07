package st::api::lims::ml_warehouse_fc_cache;

use Moose;
use MooseX::StrictConstructor;
use Carp;
use List::MoreUtils qw(any);

use st::api::lims;
use npg_tracking::util::types;
use WTSI::DNAP::Warehouse::Schema;
use WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell;

with qw/  npg_tracking::glossary::lane
          npg_tracking::glossary::tag
          npg_tracking::glossary::flowcell /;

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

=head2 flowcell_barcode

=head2 id_flowcell_lims

=head2 id_run

id_run, optional attribute.

=cut
has 'id_run' =>       ( isa             => 'Maybe[NpgTrackingRunId]',
                        is              => 'ro',
                        required        => 0,
                        lazy_build      => 1,
);
sub _build_id_run {
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
  my$id_run_rs=$self->iseq_flowcell->related_resultset('iseq_product_metrics')->search(\%search,{'columns'=>[qw(id_run)], 'distinct'=>1});
  if( my$id_run_record = $id_run_rs->next() ){
    croak 'Found more than one id_run' if($id_run_rs->next());
    return $id_run_record->id_run;
  }
  carp join q( ), 'No id_run set yet',
    ($self->has_flowcell_barcode ? ('flowcell_barcode:'.$self->flowcell_barcode) : ()),
    ($self->has_id_flowcell_lims ? ('id_flowcell_lims:'.$self->id_flowcell_lims) : ());
  return;
}

=head2 position

Position, optional attribute.

=cut
has '+position' =>       ( required        => 0, );

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

=head2 mlwh_schema

WTSI::DNAP::Warehouse::Schema connection

=cut
has 'mlwh_schema' =>     ( isa             => 'WTSI::DNAP::Warehouse::Schema',
                           is              => 'ro',
                           lazy_build      => 1,
);
sub _build_mlwh_schema {
  my $self = shift;
  return  $self->has_iseq_flowcell ?
    $self->iseq_flowcell->result_source->schema :
    WTSI::DNAP::Warehouse::Schema->connect();
}


has '_run_resultset_rows_cache' =>
                         ( isa             => 'ArrayRef',
                           traits          => ['Array'],
                           is              => 'ro',
                           lazy_build      => 1,
                           handles         => { _run_resultset_rows => 'elements'},
);
sub _build__run_resultset_rows_cache {
  my $self = shift;
  my $q = {};
  if ($self->has_id_flowcell_lims) { $q->{id_flowcell_lims}=$self->id_flowcell_lims; }
  elsif ($self->has_id_run) { $q->{id_run}=$self->id_run; }
  elsif ($self->has_flowcell_barcode) { $q->{flowcell_barcode}=$self->flowcell_barcode; }
  croak 'Either id_flowcell_lims, flowcell_barcode or id_run should be defined' if not keys %{$q};
  return [$self->iseq_flowcell->search($q,{prefetch =>[qw(sample study iseq_product_metrics)]})->all];
}

has '_position_resultset_rows_cache' =>
                         ( isa             => 'ArrayRef',
                           traits          => ['Array'],
                           is              => 'ro',
                           lazy_build      => 1,
                           handles         => { _position_resultset_rows => 'elements'},
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

sub count {
  my$self=shift;
  my@r = $self->position ? $self->_position_resultset_rows : $self->_run_resultset_rows;
  return scalar @r;
}

=head2 children

=cut
sub children {
  my $self = shift;

  my @children = ();

  if (!$self->tag_index) {

    my $package_name = ref $self;
    my $init = {'_run_resultset_rows_cache' => $self->_run_resultset_rows_cache};
    foreach my $init_attr ( qw/id_flowcell_lims flowcell_barcode id_run/) {
      my $pred = "has_$init_attr";
      if ($self->$pred) {
        $init->{$init_attr} = $self->$init_attr;
      }
    }

    if ($self->position) {
      if ($self->is_pool) {
        $init->{'position'}        = $self->position;
        my %hashed_rs = map { $_->tag_index => 1} $self->_position_resultset_rows;
        foreach my $tag_index (sort {$a <=> $b} keys %hashed_rs) {
          $init->{'tag_index'} = $tag_index;
          push @children, $package_name->new($init);
	}
      }
    } else {
      my %hashed_rs = map { $_->position => 1} $self->_run_resultset_rows;
      my @positions = sort {$a <=> $b} keys %hashed_rs;
      foreach my $position (@positions) {
        $init->{'position'}        = $position;
        push @children, $package_name->new($init);
      }
    }
  }

  return @children;
}

has 'is_pool' =>         ( isa             => 'Bool',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
);
sub _build_is_pool {
  my $self = shift;
  if ( $self->position && !$self->tag_index ) {
    return 1 if any {
      $_->entity_type eq $WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell::INDEXED_LIBRARY
    } $self->_position_resultset_rows;
  }
  return 0;
}

=head2 spiked_phix_tag_index

 Read-only integer accessor, not possible to set from the constructor.
 Defined for a lane and all tags, including tag zero

=cut
has 'spiked_phix_tag_index' => ( isa             => 'Maybe[NpgTrackingTagIndex]',
                                 is              => 'ro',
                                 init_arg        => undef,
                                 lazy_build      => 1,
);
sub _build_spiked_phix_tag_index {
  my $self = shift;

  my $tag_index;
  if ($self->position) {
    my $spike_type = $WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell::INDEXED_LIBRARY_SPIKE;
    my @rs = grep{$_->entity_type eq $spike_type} $self->_position_resultset_rows;
    my $row = shift @rs;
    if ($row) {
      croak q[Multiple spike definitions] if @rs;
      $tag_index = $row->tag_index;
      if (!$tag_index) {
        croak q[Tag index for the spike is missing];
      }
    }
  }
  return $tag_index;
}

=head2 qc_state

Same logic as found in WTSI::DNAP::Warehouse::Schema::Result::IseqFlowcell

=cut

sub qc_state {
  my $self = shift;
  if( $self->position ){
    my @r = $self->_position_resultset_rows;
    my $t = $self->tag_index;
    if( defined $t ){
      @r = grep {$_->tag_index and $_->tag_index == $t} @r;
    } else {
      @r = grep {$_->entity_type ne
          $WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell::INDEXED_LIBRARY_SPIKE } @r;
    }
    @r = grep{defined} map {$_->qc} map{$_->iseq_product_metrics}@r;
    return shift @r if @r==1;
  }
  return;
}

sub _to_delegate {
  my $package = 'WTSI::DNAP::Warehouse::Schema::Result::IseqFlowcell';
  my @l = grep {$_ ne 'qc_state'} grep {$package->can($_)} st::api::lims->driver_method_list_short(__PACKAGE__->meta->get_attribute_list);
  return \@l;
}

has '_dbix_row' => ( isa             => 'Maybe[WTSI::DNAP::Warehouse::Schema::Result::IseqFlowcell]',
                     is              => 'ro',
                     init_arg        => undef,
                     lazy_build      => 1,
                     handles         => _to_delegate(),
);
sub _build__dbix_row {
  my $self = shift;

  if ($self->position) {
    if (!$self->is_pool) {
      my @rs;
      if ($self->tag_index) {
        @rs = grep{$_->tag_index == $self->tag_index} $self->_position_resultset_rows;
      } else {
        @rs = grep {
          ( $_->entity_type eq
          $WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell::NON_INDEXED_LIBRARY
          ) or ( $_->entity_type eq
          $WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell::CONTROL_LANE
          ) } $self->_position_resultset_rows;
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

foreach my $method (_to_delegate()) {
  around $method => sub {
    my ($orig, $self) = @_;
    return $self->_dbix_row ? $self->$orig() : undef;
  };
}

=head2 to_string

Human friendly description of the object

=cut
sub to_string {
  my $self = shift;
  my $s = __PACKAGE__;
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

=item MooseX::StrictConstructor

=item Carp

=item npg_tracking::util::types

=item npg_tracking::glossary::lane

=item npg_tracking::glossary::tag

=item npg_tracking::glossary::flowcell

=item st::api::lims

=item WTSI::DNAP::Warehouse::Schema

=item WTSI::DNAP::Warehouse::Schema::Query::IseqFlowcell

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David Jackson E<lt>david.jackson@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Ltd.

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
