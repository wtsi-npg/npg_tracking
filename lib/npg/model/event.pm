#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::model::event;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use MIME::Lite;
use Sys::Hostname;
use npg::model::event_type;
use npg::model::user;
use npg::model::run;
use npg::util;

our $VERSION = '0';

my $MAIL_DOMAIN = npg::util::mail_domain();

use Readonly;
Readonly::Scalar our $LAST_INDEX => -1;
Readonly::Scalar our $DESCRIPTION_LENGTH => 255;

__PACKAGE__->mk_accessors(fields(), 'run');
__PACKAGE__->has_a(['event_type', 'user']);

sub fields {
  return qw(id_event
            id_event_type
            date
            description
            entity_id
            id_user);
}

sub init {
  my ($self) = @_;

  if($self->{entity_type_description} &&
     !$self->{id_entity_type}) {
    my $ent = npg::model::entity_type->new({
                                          description => $self->{entity_type_description},
                                          util        => $self->util(),
                                          });
    $self->{id_entity_type} = $ent->id_entity_type();
  }

  if($self->{event_type_description} &&
     !$self->{id_event_type} &&
     $self->{id_entity_type}) {
    my $ent = npg::model::event_type->new({
                                          description    => $self->{event_type_description},
                                          id_entity_type => $self->{id_entity_type},
                                          util           => $self->util(),
                                          });
    $self->{id_event_type} = $ent->id_event_type();
  }
  return $self;
}

sub create {
  my ($self, $arg_refs) = @_;
  my $util = $self->util();

  if($self->{entity_type_description} &&
     !$self->{id_entity_type}) {
    my $et = npg::model::entity_type->new({
                                          util        => $util,
                                          description => $self->{'entity_type_description'},
                                          });
    $self->{id_entity_type} = $et->id_entity_type();
  }

  if($self->{event_type_description} &&
     $self->{id_entity_type} &&
     !$self->{id_event_type}) {
    my $et = npg::model::event_type->new({
                                         util           => $util,
                                         description    => $self->{event_type_description},
                                         id_entity_type => $self->{id_entity_type},
                                        });
    $self->{event_type}    = $et;
    $self->{id_event_type} = $et->id_event_type();
  }

  if(!$self->{id_user}) {
    $self->{id_user} = $util->requestor->id_user();
  }

  # don't want to manage my own insert here just for the sake of a date
  $self->{date} ||= $util->dbh->selectall_arrayref(q(SELECT NOW()))->[0]->[0];

  # the description can only be a maximum of 255 characters
  my $description = substr $self->description, 0, $DESCRIPTION_LENGTH;
  $self->description($description);

  return $self->SUPER::create();
}

1;
__END__

=head1 NAME

npg::model::event

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 init - support load by non-primary-keys (entity_type_description and event_type_description

  my $oEvent = npg::model::event->new({
    entity_type_description => 'instrument',
    event_type_description  => 'annotation',
  });

=head2 event_type - npg::model::event_type of this event

  my $oRunEventType = $oRun->event_type();

=head2 user - npg::model::user who generated this event

  my $oUser = $oEvent->user();

=head2 create - creation handling for event & entity dictionaries

  $oEvent->create();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 GRL, by Roger Pettett

This file is part of NPG.

NPG is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/ .

=cut
