package npg_tracking::report::events;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use List::MoreUtils qw/any uniq/;
use Class::Load qw/load_class/;
use Try::Tiny;
use FindBin qw($Bin);
use Readonly;

use npg_tracking::util::types;
use npg_tracking::util::abs_path qw/abs_path/;
use npg_tracking::Schema;
use WTSI::DNAP::Warehouse::Schema;

with qw/ MooseX::Getopt
         WTSI::DNAP::Utilities::Loggable /;

our $VERSION = '0';

Readonly::Array  my @COMMON_REPORT_TYPES  => qw/subscribers/;
Readonly::Scalar my $TEMPLATE_DIR         =>
                                          q[data/npg_tracking_email/templates];

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
  isa        => 'Maybe[WTSI::DNAP::Warehouse::Schema]',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
  traits     => [ 'NoGetopt' ],
);
sub _build_schema_mlwh {
  my $self = shift;
  return WTSI::DNAP::Warehouse::Schema->connect();
}

has '_template_dir_path' => (
  isa        => 'NpgTrackingDirectory',
  is         => 'ro',
  required   => 0,
  lazy_build => 1,
);
sub _build__template_dir_path {
  return abs_path "$Bin/../$TEMPLATE_DIR";
}

sub process {
  my $self = shift;

  my $unprocessed_events = $self->schema_npg->resultset('Event')
    ->search( { notification_sent => '0000-00-00 00:00:00' } );

  my $count  = 0;
  my $scount = 0;
  while ( my $event = $unprocessed_events->next() ) {

    $count++;
    my $entity;
    try {
      $entity = $event->entity_obj();
    } catch {
      $self->info('Failed to retrieve event entity: ' . $_);
    };
    if (!$entity) {
      next;
    }
    if (!$entity->can('information')) {
      $self->info('Do not know how to report ' .
        $entity->resultsource()->name());
      next;
    }

    try {
      foreach my $report_type ($self->_report_types($entity)) {
        my $report = $self->_get_report_obj($report_type, $entity);
        $report->reports();
        $report->emit(); # should have provisions for dry_run
      }
      if (!$self->dry_run) {
        $event->mark_as_reported();
      }
      $scount++;
    } catch {
      $self->info('Error creating or sending report : ' . $_);
    };
  }

  $self->info("Successfully processed $scount events");
  my $failed = $count - $scount;
  if ($failed) {
    $self->info("Failed to process $failed events");
  }

  return ($scount, $failed);
}

sub _report_types {
  my ($self, $entity) = @_;
  my @report_types = @COMMON_REPORT_TYPES;
  if ($entity->can('event_report_types')) {
    push @report_types, $entity->event_report_types();
  }
  return @report_types;
}

sub _get_report_obj {
  my ($self, $report_type, $entity) = @_;

  my $class = 'npg_tracking::report::event2' . $report_type;
  load_class($class);
  my $ref = {
    event_entity      => $entity,
    dry_run           => $self->dry_run() ? 1 : 0,
    template_dir_path => $self->_template_dir_path()
  };
  if ($self->schema_mlwh()) {
    $ref->{'schema_mlwh'}  = $self->schema_mlwh();
  }

  return $class->new($ref);
}

1;

__END__

=head1 NAME

npg_tracking::report::events

=head1 SYNOPSIS

 npg_tracking::report::events->new()->process();
 npg_tracking::report::events->new(dry_run => 1)->process();

=head1 DESCRIPTION

 Attempts to report the events that have not been yet been reported
 and marks events as reported if successful. A number of different
 reports for different recipients can be generated for the same event.

=head1 SUBROUTINES/METHODS

=head2 dry_run

 A boolean flag. Set it to avoid sending out reports or marking events
 as reported.

=head2 schema_npg

 DBIx handle for NPG tracking database, see npg_tracking::Schema.
 This attribute will be built if not set.

=head2 schema_mlwh

 DBIx handle for a warehouse containing LIMs data, see
 C<WTSI::DNAP::Warehouse::Schema>. This attribute will be built if not set.
 
 For ease of testing this attribute can explicitly be set to undefined,
 in which case its value will not be propagated to individual reporter modules.

=head2 process

 Retrieves unprocessed events from the database, attempts to process them
 and mark them as reported. It is tolerant to errors in processing individual
 events. It is ignorant about where errors in reporting occured and whether
 some of the reports for an event that is not marked as reported were actually
 sent.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item MooseX::Getopt

=item namespace::autoclean

=item List::MoreUtils

=item Class::Load

=item Try::Tiny

=item npg_tracking::util::types

=item npg_tracking::util::abs_path

=item npg_tracking::Schema

=item WTSI::DNAP::Warehouse::Schema

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017,2021,2023 Genome Research Ltd.

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

