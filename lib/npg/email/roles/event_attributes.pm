#############
# Created By: ajb
# Created On: 2011-01-07

package npg::email::roles::event_attributes;
use strict;
use warnings;
use Moose::Role;
use Carp;
use POSIX qw(strftime);

our $VERSION = '0';

requires qw{_build_template default_recipient_host schema_connection};

=head1 NAME

npg::email::roles::event_attributes

=head1 VERSION


=head1 SYNOPSIS

  package My::EventEmailer;
  use Moose;
  with qw{npg::email::roles::event_attributes};

=head1 DESCRIPTION

Provides all the attributes needed directly relating to event email sending.

You possibly have to provide the following methods to consume this role:

  _build_template # to provide the template to use for the email
  default_recipient_host # to provide a default mail host for emails with no @y.com
  schema_connection # to provide a connection to a database
  _entity_check # to provide a string to check the entity's class against


=head1 SUBROUTINES/METHODS

=cut

has event_row => (
  isa        => 'npg_tracking::Schema::Result::Event',
  is         => 'ro',
  required   => 1,
  lazy_build => 1,
);

sub _build_event_row {
  my ($self) = @_;
  return $self->schema_connection->resultset('Event')->find( $self->id_event() );
}


has 'id_event' => (
  isa        => 'Int',
  is         => 'ro',
  required   => 1,
  lazy_build => 1,
);

sub _build_id_event {
  my ($self) = @_;
  return $self->event_row->id_event();
}


=head2 entity

returns the entity object from the event_row

You may want to put a modifier on this to check the entity type is that which was expected

=cut

has entity => (
  isa        => 'Object',
  is         => 'ro',
  lazy_build => 1,
);

sub _build_entity {
  my ($self) = @_;

  my $entity_obj = $self->event_row->entity_obj();
  croak q{Constructor argument is not a } . $self->_entity_check() . q{ event}
    if ref $entity_obj ne $self->_entity_check();

  return $entity_obj;
}

=head2 watchers

An arrayref of the watchers (members of the usergroup)

defaults to events if you don't pass in a groupname

  my $aWatchers = $oClass->watchers( $groupname );

=cut

has q{_watchers} => (
  is         => 'rw',
  isa        => 'ArrayRef[Str]',
  predicate  => q{_has_watchers},
);

sub watchers {
  my ( $self, $groupname ) = @_;

  if ( $self->_has_watchers() ) {
    return $self->_watchers();
  }

  $groupname ||= q{events};

  my $host = $self->default_recipient_host();

  # Prevent spam - but allow tests to pass. Set $USER for srpipe cronjobs.
  return [ $ENV{USER} . $host ]
    if $self->dev !~ m/^ (?: test | live ) $/msx;

  my $schema = $self->schema_connection();

  my $event_group_id = $schema->resultset('Usergroup')->
            find( { groupname => $groupname } )->id();

  my $user_rs = $schema->resultset('User')->search(
          { 'user2usergroups.id_usergroup' => $event_group_id },
          { join => 'user2usergroups' }
  );

  my %recipients;

  ######
  # create a list of the recipients that includes the originator, but ensure that they are unique
  my @recievers;
  while ( my $row = $user_rs->next() ) {
    my $name = $row->username();
    ( $name =~ m/@/msx ) || ( $name .= $host );
    $recipients{$name}++;
  }

  my $originator = $self->user();
  if ( $originator ne q{pipeline} && $originator ne q{srpipe} ) {
    ( $originator =~ m/@/msx ) || ( $originator .= $host );
    $recipients{$originator}++;
  }
  @recievers = sort keys %{recipients};

  $self->_watchers( \@recievers );

  return $self->_watchers();
}

=head2 update_event_as_notified

updates the event row notification_sent field

=cut

sub update_event_as_notified {
  my ( $self ) = @_;

  $self->event_row->notification_sent( strftime( '%F %T', localtime ) );
  $self->event_row->update();

  return 1;
}

=head2 user

The username of the person responsible for producing the event

  my $sUser = $oClass->user();

=cut

sub user {
  my ( $self ) = @_;
  return $self->event_row->user->username();
}

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

sub _build_dev {
  my ($self) = @_;

  return ( defined $ENV{dev} ) ? $ENV{dev} : 'live';
}

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


1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

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
