#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::model::event_type;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::event;
use npg::model::entity_type;
use npg::model::usergroup;
use npg::model::event_type_subscriber;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_many_through('usergroup|event_type_subscriber');
__PACKAGE__->has_many('event');
__PACKAGE__->has_a('entity_type');
__PACKAGE__->has_all();

sub fields {
  return qw(id_event_type
            id_entity_type
            description);
}

sub init {
  my $self = shift;

  if($self->{id_entity_type} &&
     $self->{description} &&
     !$self->{id_event_type}) {
    my $query = q(SELECT id_event_type
                  FROM   event_type
                  WHERE  description    = ?
                  AND    id_entity_type = ?);

    my $ref = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->{description}, $self->{id_entity_type});
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{'id_event_type'} = $ref->[0]->[0];
    }
  }
  return 1;
}


1;
__END__

=head1 NAME

npg::model::event_type

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 init - Support for initialization-by-description

=head2 events - arrayref of npg::model::events with this event_type

  my $arEvents = $oEventType->events();

=head2 usergroups - arrayref of npg::model::usergroups subscribed to notifications for this event_type

  my $arUserGroups = $oEventType->usergroups();

=head2 entity_type - npg::model::entity_type for which this event_type can be emitted

  my $oEntityType = $oEventType->entity_type();

=head2 event_types - arrayref of all npg::model::event_types();

  my $arEventTypes = $oEventType->event_types();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item npg::model

=item English

=item Carp

=item npg::model::event

=item npg::model::entity_type

=item npg::model::usergroup

=back

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
