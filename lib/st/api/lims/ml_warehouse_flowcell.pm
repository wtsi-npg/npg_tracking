package st::api::lims::ml_warehouse_flowcell;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;
use Class::Load qw/load_class/;
use Readonly;

use npg_tracking::util::types;
use st::api::lims;
use WTSI::DNAP::Warehouse::Schema;

with qw/
  npg_tracking::glossary::flowcell
  npg_tracking::glossary::lane
  npg_tracking::glossary::tag
/;

our $VERSION = '0';

Readonly::Hash my %MANUFACTURER_CONFIG => (
  q[Illumina] => {
    driver_class => q[st::api::lims::ml_warehouse_fc_cache],
    resultset    => q[IseqFlowcell],
    query_column => q[id_flowcell_lims],
  },
  q[Element Biosciences] => {
    driver_class => q[st::api::lims::ml_warehouse_flowcell::elembio],
    resultset    => q[EseqFlowcell],
    query_column => q[id_flowcell_lims],
  },
  q[Ultima Genomics] => {
    driver_class => q[st::api::lims::ml_warehouse_flowcell::ultima],
    resultset    => q[UseqWafer],
    query_column => q[batch_for_opentrons],
  },
);

Readonly::Array my @DELEGATED_METHODS => (
  qw/count children is_pool is_control qc_state spiked_phix_tag_index/,
  st::api::lims->driver_method_list_short(),
);

=head1 NAME

st::api::lims::ml_warehouse_flowcell

=head1 SYNOPSIS

  my $l = st::api::lims->new(
    id_flowcell_lims => 107441,
    driver_type      => 'ml_warehouse_flowcell'
  );

=head1 DESCRIPTION

Manufacturer-aware MLWH LIMS driver keyed by flowcell or batch id.
The driver probes Illumina, Element Biosciences and Ultima warehouse flowcell
tables, then delegates to an implementation appropriate for the matched
platform.

=head1 SUBROUTINES/METHODS

=head2 id_flowcell_lims

Primary lookup key. Required.

=head2 id_run

Optional run id. Passed through to the delegated driver when supplied.

=head2 position

Optional position or lane.

=head2 tag_index

Optional tag index.

=head2 manufacturer

Resolved manufacturer name.

=head2 free_children

Clears cached child data in the delegated driver when available.

=head2 to_string

Human-friendly description of the object.

=cut

has 'id_run' => (
  isa        => 'Maybe[NpgTrackingRunId]',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
  predicate  => 'has_id_run',
);
sub _build_id_run {
  my $self = shift;
  return $self->_delegate->id_run if $self->_delegate->can('id_run');
  return;
}

has '+position' => (
  required => 0,
);

has 'mlwh_schema' => (
  isa        => 'WTSI::DNAP::Warehouse::Schema',
  is         => 'ro',
  lazy_build => 1,
);
sub _build_mlwh_schema {
  return WTSI::DNAP::Warehouse::Schema->connect();
}

has '_manufacturer' => (
  isa        => 'Str',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__manufacturer {
  my $self = shift;

  $self->has_id_flowcell_lims or
    croak 'id_flowcell_lims should be defined';

  my @matches = ();
  foreach my $manufacturer (sort keys %MANUFACTURER_CONFIG) {
    my $config = $MANUFACTURER_CONFIG{$manufacturer};
    my $rs = $self->mlwh_schema->resultset($config->{resultset})->search(
      {$config->{query_column} => $self->id_flowcell_lims},
      {rows => 1}
    );
    if ($rs->count) {
      push @matches, $manufacturer;
    }
  }

  @matches or croak sprintf 'No flowcell records retrieved for id_flowcell_lims %s',
    $self->id_flowcell_lims;
  @matches == 1 or croak sprintf
    'Multiple manufacturers matched id_flowcell_lims %s: %s',
    $self->id_flowcell_lims, join q[, ], @matches;

  return $matches[0];
}

has '_delegate' => (
  isa        => 'Object',
  is         => 'ro',
  init_arg   => undef,
  lazy_build => 1,
  handles    => \@DELEGATED_METHODS,
);
sub _build__delegate {
  my $self = shift;

  my $config = $MANUFACTURER_CONFIG{$self->manufacturer};
  my $class = $config->{driver_class};
  load_class($class);

  my %init = (
    id_flowcell_lims => $self->id_flowcell_lims,
    mlwh_schema      => $self->mlwh_schema,
  );
  if ($self->has_id_run) {
    $init{id_run} = $self->id_run;
  }
  if ($self->has_position) {
    $init{position} = $self->position;
  }
  if ($self->has_tag_index) {
    $init{tag_index} = $self->tag_index;
  }

  return $class->new(\%init);
}

sub manufacturer {
  my $self = shift;
  return $self->_manufacturer();
}

sub free_children {
  my $self = shift;
  if ($self->_delegate->can('free_children')) {
    $self->_delegate->free_children();
  }
  return;
}

sub to_string {
  my $self = shift;
  my $s = ref $self;
  foreach my $attr (qw/id_flowcell_lims id_run position tag_index/) {
    my $pred = q[has_] . $attr;
    if ($self->can($pred) && $self->$pred) {
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

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Carp

=item Class::Load

=item Readonly

=item st::api::lims

=item WTSI::DNAP::Warehouse::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

OpenAI

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
