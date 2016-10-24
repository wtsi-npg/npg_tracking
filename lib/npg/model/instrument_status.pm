#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::model::instrument_status;

use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::user;
use npg::model::instrument_status_dict;
use npg::model::instrument;
use npg::model::event;
use npg::model::instrument_annotation;
use List::MoreUtils qw (any);

use npg::model::instrument_status_annotation;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_a(['instrument','user']);
__PACKAGE__->has_many_through('annotation|instrument_status_annotation');

sub fields {
  return qw(id_instrument_status
            id_instrument
            date
            id_instrument_status_dict
            id_user
            iscurrent
            comment);
}

sub instrument_status_dict {
  my $self = shift;
  # kill cache of instrument status dict object, as stops being able to find description
  $self->{'instrument_status_dict'} = undef;
  return $self->gen_getobj('npg::model::instrument_status_dict');
}

sub _check_order_ok {
  my $self = shift;

  my $status = $self->instrument_status_dict;
  my $new = $status->description() || q[];
  if (!$status->iscurrent) {
    croak "Status \"$new\" is deprecated";
  }
  my $instrument = $self->instrument();
  my $status_obj = $instrument->current_instrument_status();
  if(!$status_obj) { return; }

  my $current = $status_obj->instrument_status_dict->description();
  if ($current eq $new) {
    return;
  }
  if (any {$_ eq $new} @{$instrument->possible_next_statuses4status($current)}) {
    return;
  }

  croak q{Instrument } . $instrument->name() . qq{ "$new" status cannot follow current "$current" status};
}

sub create {
  my $self     = shift;
  my $util     = $self->util();
  my $dbh      = $util->dbh();
  my $tr_state = $util->transactions();

  $self->_check_order_ok();

  eval {
    my $rows = $dbh->do(q(UPDATE instrument_status
                          SET    iscurrent     = 0
                          WHERE  id_instrument = ?), {},
                        $self->id_instrument());

    my $query = q(INSERT INTO instrument_status (id_instrument,date,id_instrument_status_dict,id_user,iscurrent,comment)
                  VALUES (?,now(),?,?,1,?));

    $dbh->do($query, {},
            $self->id_instrument(),
            $self->id_instrument_status_dict(),
            $self->id_user(),
            $self->comment());

    #########
    # Sometimes we have to change automatically to the next status
    #
    my $next_status = $self->instrument->status_to_change_to();
    if ($next_status) {
      my $isd = npg::model::instrument_status_dict->new({
               util        => $util,
               description => $next_status,
            });
      #########
      # reset our iscurrent again
      #
      $dbh->do(q(UPDATE instrument_status
                 SET    iscurrent     = 0
                 WHERE  id_instrument = ?), {},
              $self->id_instrument());

      $dbh->do($query, {},
              $self->id_instrument(),
              $isd->id_instrument_status_dict(),
              $self->id_user(),
              'automatic status update');
    }

    my $idref = $dbh->selectall_arrayref('SELECT LAST_INSERT_ID()');
    $self->id_instrument_status($idref->[0]->[0]);

    $util->transactions(0);

    $query = q(SELECT evt.id_event_type
               FROM   event_type  evt,
                      entity_type ent
               WHERE  evt.id_entity_type = ent.id_entity_type
               AND    ent.description = 'instrument_status'
               AND    evt.description = 'status change');
    my $id_event_type = $dbh->selectall_arrayref($query)->[0]->[0];
    if (!$id_event_type) {
      croak qq[no id_event_type $query];
    }

    my $event = npg::model::event->new({
                                      util          => $util,
                                      id_event_type => $id_event_type,
                                      entity_id     => $self->id_instrument_status(),
                                      id_user       => $self->id_user(),
                                      description   => qq(New instrument_status: @{[$self->instrument_status_dict->description()||'unspecified']} for instrument @{[$self->instrument->name()||'unspecified']}\n@{[$self->comment()||'unspecified']}),
               });
    $event->create();

  } or do {
    $util->transactions($tr_state);
    $dbh->rollback();
    croak $EVAL_ERROR;
  };

  $util->transactions($tr_state);

  eval {
    $tr_state and $dbh->commit();
    1;

  } or do {
    $dbh->rollback();
    croak $EVAL_ERROR;
  };

  return 1;
}

sub current_instrument_statuses {
  my ($self, $limit) = @_;

  if(!$self->{'current_instrument_statuses'}) {
    my $query = qq(SELECT @{[join q(, ), $self->fields()]}
                   FROM   @{[$self->table()]}
                   WHERE iscurrent = 1
                   ORDER BY date DESC);
    if($limit) {
      $query .= qq( LIMIT $limit);
    }
    $self->{'current_instrument_statuses'} = $self->gen_getarray(ref $self, $query);
  }

  return $self->{'current_instrument_statuses'};
}

sub latest_current_instrument_status {
  my $self  = shift;

  if(!$self->{'latest_instrument_status'}) {
    my $query = qq(SELECT @{[join q(, ), $self->fields()]}
                   FROM   @{[$self->table()]}
                   WHERE  iscurrent = 1
                   AND    date      = (SELECT MAX(date) FROM @{[$self->table()]}));
    $self->{'latest_instrument_status'} = $self->gen_getarray(ref $self, $query)->[0];
  }

  return $self->{'latest_instrument_status'};
}

sub instruments {
  my ( $self ) = @_;
  if ( ! $self->{instruments} ) {
    $self->{instruments} = $self->gen_getobj( q{npg::model::instrument} )->instruments();
  }
  return $self->{instruments};
}

sub instrument_model {
  my ( $self ) = @_;
  if ( ! $self->{instrument_model} ) {
    $self->{instrument_model} = $self->util->cgi->param('inst_format');
  }
  return $self->{instrument_model} || q{};
}

sub current_instrument_status {
  my ( $self ) = @_;
  if ( $self->instrument() ) {
    return $self->instrument()->current_instrument_status();
  }
  return $self;
}

1;
__END__

=head1 NAME

npg::model::instrument_status

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 user - npg::model::user who actioned this status

  my $oOperatingUser = $oInstrumentStatus->user();

=head2 instrument - npg::model::instrument to which this instrument_status belongs

  my $oInstrument = $oInstrumentStatus->instrument();

=head2 instrument_status_dict - npg::model::instrument_status_dict for this status' id_instrument_status_dict

  my $oInstrumentStatusDict = $oInstrumentStatus->instrument_status_dict();

=head2 create - special handling for dates & iscurrent

  $oInstrumentStatus->create();

  Sets date using database's now() function
  Sets all other instrument_status for this id_instrument to iscurrent=0
  Sets this iscurrent=1 (whatever was set/unset in the object);

=head2 current_instrument_statuses - arrayref of npg::model::instrument_status with iscurrent = 1

  my $arCurrentInstrumentStatuses = $oInstrumentStatus->current_instrument_statuses();

=head2 latest_current_instrument_status - the most recent npg::model::instrument_status with iscurrent = 1

  my $oLatestCurrentInstrumentStatus = $oInstrumentStatus->latest_current_instrument_status();

=head2 instruments

short cut method to obtain an array of all instruments

=head2 instrument_model

method to obtain the model format from cgi params

=head2 current_instrument_status

returns either the current instrument status object should we have an instrument, else self

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

=item npg::model::user

=item npg::model::instrument_status_dict

=item npg::model::instrument

=item npg::model::event

=item List::MoreUtils

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 GRL, by Roger Pettett

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
