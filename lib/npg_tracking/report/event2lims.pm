package npg_tracking::report::event2lims;

use Moose;
use Carp;

use st::api::event;
use st::api::lims;

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

sub send {
  my $self = shift;
  foreach my $report ( @{$self->reports()} ) {
    if ($self->dry_run) {
      carp $report->{'message'};
    } else {
      $report->create();
    }
  }
  return;
}

1;
