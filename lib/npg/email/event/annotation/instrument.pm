#############
# Created By: ajb
# Created On: 2011-01-10

package npg::email::event::annotation::instrument;
use strict;
use warnings;
use Moose;
use Carp;
use English qw{-no_match_vars};
use Readonly;

extends qw{npg::email};

with qw{npg::email::roles::instrument};

our $VERSION = '0';

Readonly::Scalar my $TEMPLATE => 'instrument_annotation.tt2';

has q{_entity_check} => ( isa => q{Str}, init_arg => undef, is => q{ro}, default => q{npg_tracking::Schema::Result::InstrumentAnnotation} );

sub _build_template {
  my ($self) = @_;
  return $TEMPLATE;
}

with qw{npg::email::roles::event_attributes};

=head1 NAME

npg::email::event::annotation::instrument

=head1 VERSION

=head1 SYNOPSIS

  use npg::email::event::annotation::instrument;

  my $oNotify = npg::email::event::annotation::instrument->new({
    event_row                => $job,
    schema_connection        => $schema,
    email_templates_location => $solexa_templates,
  });

=head1 DESCRIPTION

This object is responsible for notifying the relevant people of annotation made on an instrument

=head1 SUBROUTINES/METHODS

=head2 run

  $oNotify->run();

This method notifies the relevant people that this status change on an instrument has occured and updates
the database to state that it has been done;

=cut

sub run {
  my ($self) = @_;

  $self->compose_email();
  $self->send_email(
    {
      body => $self->next_email(),
      to   => $self->watchers( q{engineers} ),
      subject => q{Instrument } . $self->name() . q{ has been annotated by } . $self->user(),
    }
  );

  $self->update_event_as_notified();

  return;
}

=head2 compose_email

Collect the data required for the notification email and process the e-mail
template using it. Create an email object that can be sent from the main 'run'
method.

=cut

sub compose_email {
  my ($self) = @_;

  my $template_obj = $self->email_templates_object();

  $template_obj->process(
    $self->template(),
    {
        instrument  => $self->name(),
        dev         => $self->dev(),
        annotation  => $self->event_row->description(),
    },
  ) or do {
    croak sprintf '%s error: %s',
        $template_obj->error->type(), $template_obj->error->info();
  };

  return $template_obj;
}

=head2 understands

This method is used by the npg::email::event factory to determine if it is the correct one to
return.

=cut

sub understands {
  my ( $class, $data ) = @_;

  if (
      (    $data->{event_row}
        && $data->{event_row}->event_type->description() eq q{annotation}
        && $data->{event_row}->event_type->entity_type->description() eq q{instrument_annotation} )
         ||
      (    $data->{entity_type} eq q{instrument_annotation}
        && $data->{event_type}  eq q{annotation} )
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
