#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::model::run_status;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::user;
use npg::model::run;
use npg::model::run_status_dict;
use npg::model::event;
use Date::Parse;
use DateTime;
use Readonly;

our $VERSION = '0';

Readonly::Hash our %DAYS_PER_STATUS => (
  'run complete' => 1,
  'run mirrored' => 1,
  'analysis pending' => 1,
  'analysis in progress' => 2,
  'secondary analysis in progress' => 3,
  'analysis complete' => 1,
  'archival pending' => 1,
  'analysis in progress' => 1,
  'analysis complete' => 1,
  'archival in progress' => 2,
);

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_a([qw(run user run_status_dict)]);

sub fields {
  return qw(id_run_status
            id_run
            date
            id_run_status_dict
            id_user
            iscurrent);
}

sub epoch {
  my $self = shift;
  return str2time($self->date());
}

sub create {
  my $self     = shift;
  my $util     = $self->util();
  my $dbh      = $util->dbh();
  my $tr_state = $util->transactions();

  eval {
    my $rows = $dbh->do(q(UPDATE run_status
                          SET    iscurrent = 0
                          WHERE  id_run    = ?), {},
               $self->id_run());

    my $query = q(INSERT INTO run_status (id_run,date,id_run_status_dict,id_user,iscurrent)
                  VALUES (?,now(),?,?,1));

    $dbh->do($query, {},
            $self->id_run(),
            $self->id_run_status_dict(),
            $self->id_user());

    my $idref = $dbh->selectall_arrayref('SELECT LAST_INSERT_ID()');
    $self->id_run_status($idref->[0]->[0]);

    $util->transactions(0);

    my $history = qq(Status History:\n @{[map {
                    sprintf qq([%s] %s\n),
                            $_->date(),
                            $_->run_status_dict->description();
                  } @{$self->run->run_statuses()}]});

    my $contents_of_lanes = "\n\nBatch Id: @{[$self->run->batch_id()]}\n";
    $contents_of_lanes .= 'Lanes : '.join q( ), map{$_->position} @{$self->run->run_lanes()};
    $contents_of_lanes .= "\n";

    my $desc = $self->run_status_dict->description();

    my $msg = qq($desc for run @{[$self->run->name()]}\nhttp://npg.sanger.ac.uk/perl/npg/run/@{[$self->run->name()]}\n$history\n\n$contents_of_lanes);
    my $event = npg::model::event->new({
                                      run                => $self->run(),
                                      status_description => $desc,
                                      util               => $util,
                                      id_event_type      => 1, # run_status/status change
                                      entity_id          => $self->id_run_status(),
                                      description        => $msg,
                                      });
    $event->{id_run} = $self->id_run();
    $event->create({run => $self->id_run(), id_user => $self->id_user()});

    $self->run()->instrument()->autochange_status_if_needed($desc);

    1;

  } or do {
    $util->transactions($tr_state);
    $tr_state and $dbh->rollback();
    croak $EVAL_ERROR;
  };

  $util->transactions($tr_state);

  eval {
    $tr_state and $dbh->commit();
    1;

  } or do {
    $tr_state and $dbh->rollback();
    croak $EVAL_ERROR;
  };

  return 1;
}

sub current_run_statuses {
  my ($self, $limit) = @_;

  if(!$self->{'current_run_statuses'}) {
    my $query = qq(SELECT @{[join q(, ), $self->fields()]}
                   FROM   @{[$self->table()]}
                   WHERE iscurrent = 1
                   ORDER BY date DESC);
    if($limit) {
      $query .= qq( LIMIT $limit);
    }
    $self->{'current_run_statuses'} = $self->gen_getarray(ref $self, $query);
  }

  return $self->{'current_run_statuses'};
}

sub latest_current_run_status {
  my $self = shift;

  if(!$self->{'latest_run_status'}) {
    my $query = qq(SELECT @{[join q(, ), $self->fields()]}
                   FROM   @{[$self->table()]}
                   WHERE  iscurrent = 1
                   ORDER BY date DESC
                   LIMIT 1);
    $self->{'latest_run_status'} = $self->gen_getarray(ref $self, $query)->[0];
  }

  return $self->{'latest_run_status'};
}

sub active_runs_over_last_30_days {
  my $self = shift;

  if (!$self->{'active_runs_over_last_30_days'}) {
    my $query = q{SELECT id_run, date
                  FROM   run_status
                  WHERE date > DATE_SUB(NOW(), INTERVAL 30 DAY)
                  AND   id_run_status_dict in (SELECT id_run_status_dict
                                               FROM   run_status_dict
                                               WHERE  description in ('run in progress', 'run on hold', 'run complete'))
                  ORDER BY date};
    $self->{'active_runs_over_last_30_days'} = $self->gen_getarray(ref $self, $query);
  }
  return $self->{'active_runs_over_last_30_days'};
}


sub potentially_stuck_runs {
  my ( $self ) = @_;
  my $return = {};

  my $rows = $self->_runs_at_requested_statuses();

  my $dtnow = $self->_datetime_now();

  foreach my $row ( @{ $rows } ) {
    my ( $id_run, $date, $status, $priority ) = @{ $row };
    my ( $year, $month, $day ) = $date =~ /(\d{4})-(\d{2})-(\d{2})/xms;
    my $dt = DateTime->new(
      year => $year, month => $month, day => $day, time_zone => 'UTC',
    );
    my $days = $dtnow->delta_days($dt)->in_units( q{days} );
    if ( $days >= $DAYS_PER_STATUS{$status} ) {
      push @{ $return->{$status} }, { id_run => $id_run, days => $days, priority => $priority };
    }
  }

  return $return;
}

sub _runs_at_requested_statuses {
  my ( $self ) = @_;

  if ( ! $self->{_runs_at_requested_statuses} ) {
    my @statuses_for_query = keys %DAYS_PER_STATUS;
    my $query_string = q{'} . ( join q{','}, keys %DAYS_PER_STATUS ) . q{'};

    my $query =  qq{SELECT rs.id_run, rs.date, rsd.description, r.priority
                    FROM run_status rs, run_status_dict rsd, run r
                    WHERE  rs.iscurrent = 1
                    AND    rs.id_run_status_dict = rsd.id_run_status_dict
                    AND    rs.id_run = r.id_run
                    AND    rsd.description IN ($query_string)
                    ORDER BY rsd.id_run_status_dict, rs.id_run};

    $self->{_runs_at_requested_statuses} = $self->util->dbh->selectall_arrayref( $query );
  }
  return $self->{_runs_at_requested_statuses};
}

sub _datetime_now {
  my ( $self ) = @_;
  if ( ! $self->{_datetime_now} ) {
    $self->{_datetime_now} = DateTime->now( time_zone => 'UTC' );
  }
  return $self->{_datetime_now};
}

1;
__END__

=head1 NAME

npg::model::run_status

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 user - npg::model::user who actioned this status

  my $oOperatingUser = $oRunStatus->user();

=head2 run - npg::model::run to which this run_status belongs

  my $oRun = $oRunStatus->run();

=head2 run_status_dict - npg::model::run_status_dict for this status's id_run_status_dict

  my $oRunStatusDict = $oRunStatus->run_status_dict();

=head2 epoch - POSIX epoch time based on the run_status's date

  my $iEpoch = $oRunStatus->epoch();

=head2 create - special handling for dates & iscurrent

  $oRunStatus->create();

  Sets date using database's now() function
  Sets all other run_status for this id_run to iscurrent=0
  Sets this iscurrent=1 (whatever was set/unset in the object);

=head2 current_run_statuses - arrayref of npg::model::run_status with iscurrent = 1

  my $arCurrentRunStatuses = $oRunStatus->current_run_statuses();

=head2 latest_current_run_status - the most recent npg::model::run_status with iscurrent = 1

  my $oLatestCurrentRunStatus = $oRunStatus->latest_current_run_status();

=head2 active_runs_over_last_30_days - retrieve active runs from each of the last 30 days, sorted by date

  my $active_runs_over_last_30_days = $oRunStatus->active_runs_over_last_30_days();

=head2 potentially_stuck_runs

returns a hashref, keyed on status, which contains all the runs that are over a certain time period within a current run status

  i.e. run complete => 1 day
       run mirrored => 1 day
       analysis pending => 1 day
       analysis in progress => 2 days
       secondary analysis in progress => 3 days
       analysis complete => 1 day
       archival pending => 1 day
       analysis in progress => 1 day
       analysis complete => 1 day

You get back a hashref as follows

  {
    'run complete' => [ { id_run => 1234, days => 2 }, { id_run => 2341, days => 3 } ],
    ...
  }

  my $hPotentiallyStuckRuns = $oRunStatus->potentially_stuck_runs();

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

=item npg::model::run

=item npg::model::run_status_dict

=item npg::model::event

=item Date::Parse

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
