package st::api::lims::useq_ml_warehouse;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;

use WTSI::DNAP::Warehouse::Schema;

extends 'st::api::lims::ml_warehouse::generic_driver';

our $VERSION = '0';

=head1 NAME

st::api::lims::useq_ml_warehouse

=head1 SYNOPSIS

=head1 DESCRIPTION

Implementation of the Ultimagen data C<useq_ml_warehouse> driver
for C<st::api::lims> class, the driver for Ultimagen data.

=head1 SUBROUTINES/METHODS

=head2 to_string

Human-friendly description of the object.
Inherited from parent C<st::api::lims::useq_ml_warehouse>.

=head2 id_run

NPG tracking run id, required.
Inherited from parent C<st::api::lims::useq_ml_warehouse>.

=head2 tag_index

Tag index, optional attribute.
Inherited from parent C<st::api::lims::useq_ml_warehouse>.

=head2 mlwh_schema

WTSI::DNAP::Warehouse::Schema connection.
Inherited from parent C<st::api::lims::useq_ml_warehouse>.
This class implements a builder.

=cut

sub _build_mlwh_schema {
  return WTSI::DNAP::Warehouse::Schema->connect();
}

=head2 is_pool

Inherited from parent C<st::api::lims::useq_ml_warehouse>.

=head2 count

Number of underlying records used for evaluating this object.
Errors if no database product rows are found for this run.

=head2 children

A list of child objects for this entity. Expected to be non-empty only for
a run-level entity. Errors if no database product rows are found for this run.

=cut

has '_lchildren' => (
  isa         => 'ArrayRef',
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

  if (!$self->tag_index) { # This object is for a run.

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
          ordered_by => 'tag_index'
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

=head2 spiked_phix_tag_index

NPG tag index for Ultimagen sequencing control.
Read-only integer attribute, not possible to set from the constructor.
Inherited from parent C<st::api::lims::useq_ml_warehouse>.

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

has '_dbix_row' => (
  isa        => 'Maybe[DBIx::Class::Row]',
  is         => 'bare',
  init_arg   => undef,
  lazy_build => 1,
  handles    => _to_delegate(),
  reader     => '_get_dbix_row',
);

sub _build__dbix_row {
  my $self = shift;

  if ($self->tag_index) {
    my $rs = $self->mlwh_schema->resultset('UseqProductMetric')
         ->search({id_run => $self->id_run, tag_index => $self->tag_index});
    my $row = $rs->next;
    $row or croak 'No database record retrieved for ' . $self->to_string;
    croak 'Multiple database records for ' . $self->to_string if $rs->next;
    return $row->useq_wafer;
  }

  return;
}

foreach my $method (_to_delegate()) {
  around $method => sub {
    my ($orig, $self) = @_;
    return $self->_get_dbix_row() ? $self->$orig() : undef;
  };
}

sub _to_delegate {
  my $package = 'WTSI::DNAP::Warehouse::Schema::Result::UseqWafer';
  return [ grep { $package->can($_) }
           st::api::lims->driver_method_list_short() ];
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
