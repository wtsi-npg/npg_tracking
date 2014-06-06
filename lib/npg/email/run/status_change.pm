#############
# Created By: jo3
# Created On: 2010-02-10

package npg::email::run::status_change;
use strict;
use warnings;
use Moose;
extends qw{npg::email::run};

use Carp;
use English qw{-no_match_vars};
use Moose::Util::TypeConstraints;
use POSIX qw(strftime);
use st::api::event;
use Readonly;

our $VERSION = '0';

Readonly::Scalar my $TEMPLATE => 'run_status_change.tt2';

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


has event_row => (
    isa        => 'npg_tracking::Schema::Result::Event',
    is         => 'ro',
    required   => 1,
    lazy_build => 1,
);


has 'id_event' => (
    isa        => 'Int',
    is         => 'ro',
    required   => 1,
    lazy_build => 1,
);


has id_run => (
    is         => 'ro',
    isa        => 'Int',
    lazy_build => 1,
);


has entity => (
    isa        => 'npg_tracking::Schema::Result::RunStatus',
    is         => 'ro',
    lazy_build => 1,
);


has status_description => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);


has batch_details => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
);


has watchers => (
    is         => 'ro',
    isa        => 'ArrayRef[Str]',
    lazy_build => 1,
);


has template => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);


has dev => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);


# Check for the pathological case where the user supplies both an event db row
# AND an event id, but they don't correspond.
around BUILDARGS => sub {
    my ( $orig, $class, $args ) = @_;

    if ( defined $args->{event_row} && defined $args->{id_event} ) {

        croak "Mismatched event_row and id_event constructor arguments\n("
             . __PACKAGE__ . " requires only one of these)\n\n"
             if $args->{event_row}->id_event() != $args->{id_event};

    }

    return $class->$orig($args);
};


sub _build_dev {
    my ($self) = @_;
    return ( defined $ENV{dev} ) ? $ENV{dev} : 'live';
}


sub _build_event_row {
    my ($self) = @_;
    return $self->schema_connection->resultset('Event')->find( $self->id_event() );
}


sub _build_id_event {
    my ($self) = @_;
    return $self->event_row->id_event();
}


sub _build_template {
    my ($self) = @_;
    return $TEMPLATE;
}


sub _build_entity {
    my ($self) = @_;

    my $entity_obj = $self->event_row->entity_obj;

    croak 'Constructor argument is not a run status event'
        if ref $entity_obj ne 'npg_tracking::Schema::Result::RunStatus';

    return $entity_obj;
}


sub _build_id_run {
    my ($self) = @_;
    return $self->entity->id_run();
}

sub _build_status_description {
    my ($self) = @_;
    return $self->entity->run_status_dict->description();
}


sub _build_watchers {
    my ($self) = @_;

    my $host = $self->default_recipient_host();

    # Prevent spam - but allow tests to pass. Set $USER for srpipe cronjobs.
    my $dev = $ENV{dev} ? $ENV{dev} : 'live';
    return [ $ENV{USER} . $host ]
        if $dev !~ m/^ (?: test | live ) $/msx;

    my $schema = $self->schema_connection();

    my $event_group_id = $schema->resultset('Usergroup')->
                            find( { groupname => 'events' } )->id();

    my $user_rs = $schema->resultset('User')->search(
                    { 'user2usergroups.id_usergroup' => $event_group_id },
                    { join => 'user2usergroups' }
    );

    my $list = [];
    while ( my $row = $user_rs->next() ) {
        my $name = $row->username();
        ( $name =~ m/@/msx ) || ( $name .= $host );
        push @{ $list }, $name;
    }

    return $list;
}


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

    $self->event_row->notification_sent( strftime( '%F %T', localtime ) );
    $self->event_row->update();

    return;
}


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
        croak sprintf '%s error: %s',
            $template_obj->error->type(), $template_obj->error->info();
    };

    return $template_obj;
}


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


no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__


=head1 NAME

npg::email::run::status_change

=head1 VERSION


=head1 SYNOPSIS

    Supply either a DBIx event row or an event table row id.

    my $e_notify = npg::email::run::status_change->
                     new( { event_row => $Event_Row_obj } );

    Or:

    my $e_notify = npg::email::run::status_change->
                     new( { id_event => <int> } );

=head1 DESCRIPTION

Note, this module is now deprecated, and you shoudl use npg::email::event::status_change::run instead

When passed a run-status-change event row (or row id) send whatever emails
are required.

=head1 SUBROUTINES/METHODS

=head2 run

This method runs the relevant processing when a run has a status change to
send out emails, and record the successful sending, to requested parties
(Project related people from Sequencescape).

=head2 compose_email

Collect the data required for the notification email and process the e-mail
template using it. Create an email object that can be sent from the main 'run'
method.

=head2 compose_st_reports

Collect the data required for the sequencescape event update notification.
Create st::api::event objects for each lane and return them in an arrayref for
posting from the main 'run' method.

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

John O'Brien

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by John O'Brien (jo3@sanger.ac.uk)

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
