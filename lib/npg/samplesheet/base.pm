package npg::samplesheet::base;

use Moose;
use namespace::autoclean;
use Carp;
use Readonly;
use MooseX::Getopt::Meta::Attribute::Trait::NoGetopt;

use npg_tracking::Schema;
use st::api::lims;
use WTSI::DNAP::Warehouse::Schema;

with 'npg_tracking::glossary::run';

our $VERSION = '0';

=head1 NAME

npg::samplesheet::base

=head1 SYNOPSIS

=head1 DESCRIPTION

A parent class for samplesheet generator. Provides common attributes.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=cut

Readonly::Scalar my $SAMPLESHEET_PATH => 'samplesheets/';
Readonly::Scalar my $LIMS_DRIVER_TYPE => 'ml_warehouse';

=head1 SUBROUTINES/METHODS

=cut

=head2 samplesheet_path

A directory where the samplesheet will be created, an optional attribute.

=cut

has 'samplesheet_path' => (
  'isa'        => 'Str',
  'is'         => 'ro',
  'default'    => $SAMPLESHEET_PATH,
);


=head2 id_run

Run ID, an optional attribute.

=cut

has '+id_run' => (
  'required'   => 0,
);


=head2 batch_id

LIMS batch ID, an optional attribute. If not set, either C<id_run> or
C<run> attribute should be set.

=cut

has 'batch_id' => (
  'isa' => 'Str|Int',
  'is'  => 'ro',
  'lazy_build' => 1,
  'required'   => 0,
);
sub _build_batch_id {
  my $self = shift;
  if (!$self->id_run) {
    croak 'Run ID is not supplied, cannot get LIMS batch ID';
  }
  my $batch_id = $self->run()->batch_id();
  if (!defined $batch_id) {
    croak 'Batch ID is not set in the database record for run ' . $self->id_run;
  }

  return $batch_id;
}


=head2 npg_tracking_schema

An attribute, DBIx Schema object for the tracking database.

=cut

has 'npg_tracking_schema' => (
  'isa'        => 'npg_tracking::Schema',
  'traits'     => [ 'NoGetopt' ],
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build_npg_tracking_schema {
  my ($self) = @_;
  my$s = $self->has_tracking_run() ?
         $self->run()->result_source()->schema() :
         npg_tracking::Schema->connect();
  return $s
}

=head2 mlwh_schema
 
DBIx schema class for ml_warehouse access.

=cut

has 'mlwh_schema' => (
  'isa'        => 'WTSI::DNAP::Warehouse::Schema',
  'traits'     => [ 'NoGetopt' ],
  'is'         => 'ro',
  'required'   => 0,
  'lazy_build' => 1,
);
sub _build_mlwh_schema {
  return WTSI::DNAP::Warehouse::Schema->connect();
}


=head2 run

An attribute, DBIx object for a row in the run table of the tracking database.

=cut

has 'run' => (
  'isa'        => 'npg_tracking::Schema::Result::Run',
  'traits'     => [ 'NoGetopt' ],
  'is'         => 'ro',
  'predicate'  => 'has_tracking_run',
  'lazy_build' => 1,
);
sub _build_run {
  my $self=shift;

  if (!$self->id_run) {
    croak 'Run ID is not available, cannot retrieve run database record';
  }
  my $run = $self->npg_tracking_schema->resultset(q(Run))->find($self->id_run);
  if (!$run) {
    croak 'The database record for run ' . $self->id_run  . ' does not exist';
  }

  return $run;
}


=head2 lims

An attribute, an array of st::api::lims type objects.

To generate a samplesheet for the whole run, provide an array of
at::api::lims objects for all lanes of the run.

This attribute should normally be provided by the caller via the
constuctor. If the attribute is not provided, it is built automatically,
using the ml_warehouse lims driver.

=cut

has 'lims' => (
  'isa'        => 'ArrayRef[st::api::lims]',
  'traits'     => [ 'NoGetopt' ],
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build_lims {
  my $self=shift;

  my $run_lims = st::api::lims->new(
    driver_type      => $LIMS_DRIVER_TYPE,
    id_flowcell_lims => $self->batch_id,
    mlwh_schema      => $self->mlwh_schema
  );

  return [$run_lims->children()];
};

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Readonly

=item Carp

=item MooseX::Getopt::Meta::Attribute::Trait::NoGetopt

=item WTSI::DNAP::Warehouse::Schema

=item npg_tracking::Schema

=item  st::api::lims

=item npg_tracking::glossary::run

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David K. Jackson E<lt>david.jackson@sanger.ac.ukE<gt>

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2019, 2020, 2023 Genome Research Ltd.

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

