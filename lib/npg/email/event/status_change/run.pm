#############
# Created By: ajb
# Created On: 2011-01-06

package npg::email::event::status_change::run;
use strict;
use warnings;
use Moose;
use Carp;
use English qw{-no_match_vars};
use st::api::event;
use Readonly;

extends qw{npg::email::run};

our $VERSION = '0';

Readonly::Scalar my $TEMPLATE => 'run_status_change.tt2';

has q{_entity_check} => ( isa => q{Str}, init_arg => undef, is => q{ro}, default => q{npg_tracking::Schema::Result::RunStatus} );

sub _build_template {
  my ($self) = @_;
  return $TEMPLATE;
}

with qw{npg::email::roles::event_attributes};

Readonly::Scalar my $FAMILIES => {
        'run pending'              => 'start',
        'analysis pending'         => 'start',
        'archival pending'         => 'start',
        'analysis prelim'          => 'start',
        'qc review pending'        => 'start',
        'run cancelled'            => 'complete',
        'run complete'             => 'complete',
        'analysis complete'        => 'complete',
        'analysis cancelled'       => 'complete',
        'run archived'             => 'complete',
        'analysis prelim complete' => 'complete',
        'run quarantined'          => 'complete',
        'run stopped early'        => 'complete',
        'qc complete'              => 'complete',
        'data discarded'           => 'complete',
};

=head1 NAME

npg::email::event::status_change::run

=head1 VERSION

=head1 SYNOPSIS

  use npg::email::event::status_change::run;

  my $oNotify = npg::email::event::status_change::run->new({
    event_row                => $job,
    schema_connection        => $schema,
    email_templates_location => $solexa_templates,
  });

=head1 DESCRIPTION

This object is responsible for notifying the relevant people of a change of run status

=head1 SUBROUTINES/METHODS

=head2 run

  $oNotify->run();

This method notifies the relevant people that this status change on a run has occured and updates
the database to state that it has been done;

=cut

sub run {
  my ($self) = @_;

  $self->compose_email();
  $self->send_email(
    {
      body => $self->next_email(),
      to   => $self->watchers(),
      subject => q{Run } . $self->id_run()
               . q{ is at "} . $self->status_description() . q{"},
    }
  );

  my $st_reports = $self->compose_st_reports();

  foreach my $report ( @{$st_reports} ) { $report->create(); }

  $self->update_event_as_notified();

  return;
}

=head2 status_description

The status description that is for this event

=cut

has status_description => (
  is         => 'ro',
  isa        => 'Str',
  lazy_build => 1,
);

sub _build_status_description {
  my ($self) = @_;

  return $self->entity->run_status_dict->description();
}

=head2 compose_email

Collect the data required for the notification email and process the e-mail
template using it. Create an email object that can be sent from the main 'run'
method.

=cut

sub compose_email {
  my ($self) = @_;

  my $details      = $self->batch_details();
  my $template_obj = $self->email_templates_object();

  $template_obj->process(
    $self->template(),
    {
      run    => $self->id_run(),
      lanes  => $details->{lanes},
      status => $self->status_description(),
      dev    => $self->dev(),
    },
  ) or do {
    croak sprintf '%s error: %s', $template_obj->error->type(), $template_obj->error->info();
  };

  return $template_obj;
}


=head2 compose_st_reports

Collect the data required for the sequencescape event update notification.
Create st::api::event objects for each lane and return them in an arrayref for
posting from the main 'run' method.

=cut

sub compose_st_reports {
  my ($self) = @_;

  my $status = $self->status_description();
  my $id_run = $self->id_run();

  my $message = sprintf q[Run %d : %s], $id_run, $status;

  my @reports;
  foreach my $lane ( @{ $self->batch_details->{lanes} } ) {
    my $ref = {
          eventful_id   => $lane->{request_id},
          eventful_type => ucfirst $lane->{req_ent_name},
          location      => $lane->{position},
          identifier    => $id_run,
          key           => $status,
          message       => $message,
          family        => $FAMILIES->{$status} || 'update',
    };

    # We could send each lane report here, but I've chosen to separate the
    # steps so that testing is easier. A consequence is that this step is
    # all or nothing - if one lane fails, no reports are sent. Is this
    # good or bad?

    push @reports, st::api::event->new($ref);
  }

  return \@reports;
}


=head2 understands

This method is used by the npg::email::event factory to determine if it is the correct one to
return.

=cut

sub understands {
  my ( $class, $data ) = @_;

  if (
      (    $data->{event_row}
        && $data->{event_row}->event_type->description() eq q{status change}
        && $data->{event_row}->event_type->entity_type->description() eq q{run_status} )
         ||
      (    $data->{entity_type} eq q{run_status}
        && $data->{event_type}  eq q{status_change} )
     ) {
    return $class->new( $data );
  }

  return;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English -no_match_vars

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL, by Andy Brown (ajb@sanger.ac.uk)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
