package st::api::lims::ml_warehouse_flowcell::ultima;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;
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

Readonly::Scalar my $LIMS_RESULT_CLASS =>
  'WTSI::DNAP::Warehouse::Schema::Result::UseqWafer';
Readonly::Array my @DELEGATED_METHODS =>
  grep { $LIMS_RESULT_CLASS->can($_) }
  st::api::lims->driver_method_list_short(__PACKAGE__->meta->get_attribute_list);

=head1 NAME

st::api::lims::ml_warehouse_flowcell::ultima

=head1 SYNOPSIS

  my $d = st::api::lims::ml_warehouse_flowcell::ultima->new(
    id_flowcell_lims => '107185_NT1882031W_2'
  );

=head1 DESCRIPTION

Ultima Genomics wafer-table-backed MLWH LIMS driver.

=head1 SUBROUTINES/METHODS

=head2 manufacturer

=head2 children

=head2 is_pool

=head2 is_control

=head2 qc_state

=head2 copy_init_attrs

=head2 to_string

=cut

has '+position' => (
  required => 0,
  trigger => \&_position_filter,
);
sub _position_filter {
  my ($self, $position) = @_;
  ($position == 1) or croak "Cannot assign $position to position. " .
    'The value can only be either 1 or undefined.';
  return;
}

sub manufacturer {
  return q[Ultima Genomics];
}

has 'id_run' => (
  isa        => 'Maybe[NpgTrackingRunId]',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
  predicate  => 'has_id_run',
);
sub _build_id_run {
  my $self = shift;

  my %id_runs = map { $_ => 1 }
    grep { defined }
    map { $_->id_run }
    map { $_->useq_product_metrics } $self->_wafer_rows;

  my @id_runs = sort { $a <=> $b } keys %id_runs;
  if (@id_runs) {
    @id_runs == 1 or croak 'Found more than one id_run';
    return $id_runs[0];
  }

  return;
}

has 'mlwh_schema' => (
  isa        => 'WTSI::DNAP::Warehouse::Schema',
  is         => 'ro',
  lazy_build => 1,
);
sub _build_mlwh_schema {
  return WTSI::DNAP::Warehouse::Schema->connect();
}

has 'spiked_phix_tag_index' => (
  isa        => 'Maybe[NpgTrackingTagIndex]',
  is         => 'ro',
  init_arg   => undef,
  lazy_build => 1,
);

has '_wafer_rows_cache' => (
  isa        => 'ArrayRef',
  traits     => ['Array'],
  is         => 'ro',
  lazy_build => 1,
  handles    => { _wafer_rows => 'elements' },
);
sub _build__wafer_rows_cache {
  my $self = shift;

  $self->has_id_flowcell_lims or
    croak 'id_flowcell_lims should be defined';

  return [
    $self->mlwh_schema->resultset('UseqWafer')->search(
      {id_wafer_lims => $self->id_flowcell_lims},
      {prefetch => [qw/sample study useq_product_metrics/]}
    )->all
  ];
}

has '_rows_cache' => (
  isa        => 'ArrayRef',
  traits     => ['Array'],
  is         => 'ro',
  init_arg   => undef,
  lazy_build => 1,
  handles    => {
    _rows  => 'elements',
    count  => 'count',
  },
);
sub _build__rows_cache {
  my $self = shift;

  my @rows = $self->_wafer_rows;
  if ($self->has_tag_index && $self->tag_index) {
    @rows = grep { $self->_row_tag_index($_) == $self->tag_index } @rows;
  }
  return \@rows;
}

sub children {
  my $self = shift;

  my @children = ();
  if (!$self->tag_index) {
    my $package_name = ref $self;
    my $init = $self->copy_init_attrs();

    my %tag_indices = ();
    foreach my $row ($self->_rows) {
      $tag_indices{$self->_row_tag_index($row)} = 1;
    }
    foreach my $tag_index (sort { $a <=> $b } keys %tag_indices) {
      push @children, $package_name->new({%{$init}, tag_index => $tag_index});
    }
  }

  return @children;
}

sub is_pool {
  my $self = shift;
  return $self->tag_index ? 0 : 1;
}

sub is_control {
  my $self = shift;
  my $row = $self->_get_dbix_row();
  return $row ? ($row->entity_type =~ /control/xms ? 1 : 0) : undef;
}

sub qc_state {
  my $self = shift;
  my %values = map { $_ => 1 }
    grep { defined }
    map { $_->qc }
    map { $_->useq_product_metrics } $self->_rows;
  my @values = keys %values;
  return @values == 1 ? $values[0] : undef;
}

sub _build_spiked_phix_tag_index {
  my $self = shift;
  my $id_run = $self->id_run;
  if (defined $id_run) {
    my $rs = $self->mlwh_schema->resultset('UseqProductMetric')->search(
      {id_run => $id_run, is_sequencing_control => 1}
    );
    my $row = $rs->next;
    $row && $rs->next && croak 'Multiple rows for sequencing control';
    return $row ? $row->tag_index : undef;
  }
  return;
}

sub _build_dbix_row {
  my $self = shift;
  if (!$self->has_tag_index || !$self->tag_index) {
    return;
  }

  my @rows = $self->_rows;
  if (my $row = shift @rows) {
    @rows and croak 'Multiple entities for ' . $self->to_string;
    return $row;
  }

  croak 'No record retrieved for ' . $self->to_string;
}

sub copy_init_attrs {
  my $self = shift;

  my $init = {
    id_flowcell_lims => $self->id_flowcell_lims,
    mlwh_schema      => $self->mlwh_schema,
  };
  if ($self->has_id_run) {
    $init->{id_run} = $self->id_run;
  }
  if ($self->has_position) {
    $init->{position} = $self->position;
  }

  return $init;
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

has 'dbix_row' => (
  isa        => "Maybe[$LIMS_RESULT_CLASS]",
  is         => 'bare',
  init_arg   => undef,
  lazy_build => 1,
  handles    => \@DELEGATED_METHODS,
  reader     => '_get_dbix_row',
  builder    => '_build_dbix_row',
);

foreach my $method (@DELEGATED_METHODS) {
  around $method => sub {
    my ($orig, $self) = @_;
    return $self->_get_dbix_row() ? $self->$orig() : undef;
  };
}

sub _row_tag_index {
  my ($self, $row) = @_;

  my %tag_indices = map { $_ => 1 }
    grep { defined && $_ != 0 }
    map { $_->tag_index } $row->useq_product_metrics;
  my @tag_indices = sort { $a <=> $b } keys %tag_indices;
  if (@tag_indices) {
    @tag_indices == 1 or croak
      'Multiple tag indices linked to a single useq_wafer row';
    return $tag_indices[0];
  }

  my @rows = sort {
    ($a->tag_sequence // q[]) cmp ($b->tag_sequence // q[])
  } $self->_wafer_rows;

  my $index = 0;
  foreach my $wafer_row (@rows) {
    $index++;
    return $index if $wafer_row->id_useq_wafer_tmp == $row->id_useq_wafer_tmp;
  }

  croak 'Failed to derive tag index for useq_wafer row';
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

=item Readonly

=item st::api::lims

=item WTSI::DNAP::Warehouse::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Control-only product rows are not represented in C<useq_wafer>, so this
driver exposes the wafer-linked libraries only.

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
