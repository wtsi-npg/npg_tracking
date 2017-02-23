package npg_tracking::report::event2lims;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;

use st::api::event;
use st::api::lims;

with 'WTSI::DNAP::Utilities::Loggable';

our $VERSION = '0';

has 'dry_run' => (
  isa       => 'Bool',
  is        => 'ro',
);

has 'event_entity' => (
  is       => 'ro',
  required => 1,
  isa      => 'DBIx::Class::Row',
);

has 'lims' => (
  is         => 'ro',
  required   => 0,
  isa        => 'ArrayRef[st::api::lims]',
  lazy_build => 1,
);
sub _build_lims {
  my $self = shift;
  return [st::api::lims->new(
    id_run      => $self->event_entity->id_run(),
    batch_id    => $self->event_entity->run->batch_id(),
    driver_type => 'xml'
  )->children()];
}

has 'reports' => (
  is         => 'ro',
  required   => 0,
  isa        => 'ArrayRef',
  init_arg   => undef,
  lazy_build => 1,
);
sub _build_reports {
  my $self = shift;

  my $status  = $self->event_entity->description();
  my $id_run  = $self->event_entity->id_run();

  my @reports;
  foreach my $lane ( @{$self->lims()} ) {
    push @reports, st::api::event->new({
      eventful_id   => $lane->request_id(),
      eventful_type => 'Request',
      location      => $lane->position,
      identifier    => $id_run,
      key           => $status,
      message       => sprintf q[Run %d : %s], $id_run, $status,
    });
  }

  return \@reports;
}

sub emit {
  my $self = shift;
  foreach my $report ( @{$self->reports()} ) {
    if ($self->dry_run) {
      $self->info('DRY RUN ' . $report->{'message'});
    } else {
      $report->create();
    }
  }
  return;
}

1;
__END__

=head1 NAME

npg_tracking::report::event2lims

=head1 SYNOPSIS

 npg_tracking::report::event2lims->new(event_entity => $run_status_row)->emit();
 
=head1 DESCRIPTION

 Reports a new run status to LIMs by sending an XML message. Retrieves LIMs identifies
 from LIMs XML API fro a batch.

=head1 SUBROUTINES/METHODS

=head2 dry_run

 An optional boolean flag. Set it to avoid sending out reports.

=head2 event_entity

 A DBIx row object for the run_status table of the tracking database.
 A required attribute.

=head2 lims

 An array of lane-level st::api::lims type objects obtained using the xml driver type,
 an optional attribute, will be built if not set.

=head2 reports

 An array of generated reports. This attribute cannot be set via a constructor.

=head2 emit

 Builds reports and either posts them or, if dry_run is true, prints short report
 content. 

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Carp

=item WTSI::DNAP::Utilities::Loggable

=item st::api::event

=item st::api::lims

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 GRL

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
