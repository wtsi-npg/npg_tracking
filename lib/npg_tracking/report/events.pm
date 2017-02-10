package npg_tracking::report::events;

use Moose;
use MooseX::Getopt;
use namespace::autoclean;
use Class::Load qw/load_class/;
use List::MoreUtils qw/any uniq/;
use Readonly;
use Carp;

use npg_tracking::Schema;

our $VERSION = '0';

Readonly::Array  my @COMMON_REPORT_TYPES  => qw/subscribers/;
Readonly::Scalar my $WH_SCHEMA_CLASS_NAME => q[WTSI::DNAP::Warehouse::Schema];

has 'dry_run' => (
  isa       => 'Bool',
  is        => 'ro',
);

has 'schema_npg' => (
  isa        => 'npg_tracking::Schema',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
  traits     => [ 'NoGetopt' ],
);
sub _build_schema_npg {
  return npg_tracking::Schema->connect();
}

has 'schema_mlwh' => (
  isa        => "Maybe[$WH_SCHEMA_CLASS_NAME]",
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
  traits     => [ 'NoGetopt' ],
);
sub _build_schema_mlwh {
  my $s;
  try {
    load_class($WH_SCHEMA_CLASS_NAME);
    $s = $WH_SCHEMA_CLASS_NAME->connect();
  } catch {
    carp $_;
  };
  return $s;
}

sub process {
  my $self = shift;

  my $unprocessed_events = $self->schema_npg->resultset('Event')
    ->search( { notification_sent => '0000-00-00 00:00:00' } );

  my $count  = 0;
  my $scount = 0;
  while ( my $event = $unprocessed_events->next() ) {

    $count++;
    my $entity = $event->entity_obj();

    if (!$entity) {
      carp 'Failed to retrieve event entity for ';
      next;
    }
    if (!$entity->can('information')) {
      carp 'Do not know how to report ' . $entity->resultsource()->name();
      next;
    }

    try {
      foreach my $report_type ($self->_report_types($entity)) {
        my $report = $self->_get_report_obj($report_type, $entity);
        $report->reports();
        $report->emit(); # should have provisions for dry_run
        if (!$self->dry_run) {
          $event->mark_as_reported();
        }
      }
      $scount++;
    } catch {
      carp 'Error creating or sending report : ' . $_;
    };
  }

  carp "Successfully processed $scount events";
  my $failed = $scount - $count;
  if ($failed) {
    carp "Failed to process $failed events";
  }

  return $scount;
}

sub _report_types {
  my ($self, $entity) = @_;
  my @report_types = @COMMON_REPORT_TYPES;
  if ($entity->can('event_report_types')) {
    push @report_types, $entity->event_report_types();
  }
  @report_types = sort uniq @report_types;
  return @report_types;
}

sub _get_report_obj {
  my ($self, $report_type, $entity) = @_;

  my $class = 'npg_tracking::report::event2' . $report_type;
  load_class($class);
  my $ref = {
      event_entity => $entity,
      dry_run      => $self->dry_run() ? 1 : 0
  };
  if ($report_type ne 'lims' && $self->schema_mlwh()) {
    $ref->{'schema_mlwh'}  = $self->schema_mlwh();
  }
  return $class->new($ref);
}

1;
