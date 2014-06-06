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
use Date::Calc qw(Add_Delta_Days);
use npg::model::user;
use npg::model::instrument_status_dict;
use npg::model::instrument;
use npg::model::event;
use npg::model::instrument_annotation;
use List::Util qw(sum reduce);
use List::MoreUtils qw (any);

use npg::model::instrument_status_annotation;

our $VERSION = '0';

use Readonly;
Readonly::Scalar our $FOURTH_ARRAY_ELEMENT               => 3;
Readonly::Scalar our $DEFAULT_INSTRUMENT_UPTIME_INTERVAL => 90;
Readonly::Scalar our $HOURS_IN_DAY                       => 24;
Readonly::Scalar our $MINUTES_IN_HOUR                    => 60;
Readonly::Scalar our $PERCENTAGE                         => 100;
Readonly::Scalar our $DAYS_TO_SUBTRACT                   => 30;


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
  $self->{instrument_status_dict} = undef; # kill cache of instrument status dict object, as stops being able to find description
  return $self->gen_getobj('npg::model::instrument_status_dict');
}

sub _check_order_ok {
  my $self = shift;

  my $status = $self->instrument_status_dict;
  my $new = $status->description() || q[];
  if (!$status->iscurrent) {
    croak "Status \"$new\" is depricated";
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

sub _request_approval {
  my $self = shift;

  my $new_status = $self->instrument_status_dict->description() || q[];
  if ($new_status ne 'up') {
    return;
  }

  my $requestor  = $self->util()->requestor();
  my $instrument = $self->instrument();
  my $cis_desc   = $instrument->current_instrument_status->instrument_status_dict->description();

  if ($cis_desc eq 'request approval' &&
      !$requestor->is_member_of('approvers')) {
    croak "@{[$requestor->username()]} is not a member of 'approvers' usergroup";
  }
  return;
}

sub create {
  my $self     = shift;
  my $util     = $self->util();
  my $dbh      = $util->dbh();
  my $tr_state = $util->transactions();

  $self->_request_approval();
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

sub utilisation {
  my ($self, $type) = @_;
  my $util  = $self->util();
  my $dbh   = $util->dbh();
  my $query;

  if ($type && $type eq 'hour') {
    $query = q(CREATE TEMPORARY TABLE date_range(date DATETIME NOT NULL));
  } else {
    $query = q(CREATE TEMPORARY TABLE date_range(date DATE NOT NULL));
  }
  $dbh->do($query, {});

  Readonly::Scalar my $INTERVAL => 30;
  Readonly::Scalar my $HOURS_IN_DAY => 24;
  for my $i (1..$INTERVAL) {
    if ($type && $type eq 'hour') {
      for my $h (0..($HOURS_IN_DAY-1)) {
        $dbh->do(q(INSERT INTO date_range VALUES(DATE_SUB(NOW(), INTERVAL ? HOUR))), {}, $i*$HOURS_IN_DAY+$h);
      }
    } else {
      $query = q(INSERT INTO date_range VALUES(DATE_SUB(NOW(), INTERVAL ? DAY)));
      $dbh->do($query, {}, $i);
    }
  }

  my $ic = scalar @{$self->instrument->current_instruments()};
  if ($type && $type eq 'hour') {
    $query = q{SELECT DATE_FORMAT(date_range.date, '%Y-%m-%d %H') AS date,
               FORMAT((100*COUNT(DISTINCT(id_instrument))/?), 2) AS perc_utilisation
               FROM   date_range
               LEFT JOIN
                 (SELECT starts.id_run, starts.id_instrument,
                         ifnull(starts.start_hour, date_sub(now(), interval 37 day)) as start,
                         ifnull(ends.end_hour, now()) as end
                  FROM (SELECT r.id_run, id_instrument, rs.date AS start_hour
                        FROM   run r,
                               run_status rs,
                               run_status_dict rsd
                        WHERE  rs.id_run_status_dict = rsd.id_run_status_dict
                        AND    r.id_run = rs.id_run
                        AND    rsd.description = 'run in progress'
                        AND    rs.date > date_sub(now(), interval 37 day)) starts
                  LEFT OUTER JOIN
                    (SELECT id_run, rs.date AS end_hour
                     FROM   run_status rs,
                            run_status_dict rsd
                     WHERE  rs.id_run_status_dict = rsd.id_run_status_dict
                     AND    rsd.description in('run mirrored',
                                'run cancelled',
                                'run quarantined',
                                'data discarded',
                                'run stopped early')
                     AND    rs.date > date_sub(now(), interval 37 day)) ends
                  ON starts.id_run = ends.id_run
                  ORDER BY id_run) runs
               ON  runs.start <= date_range.date
               AND runs.end   >= date_range.date
               GROUP BY DATE_FORMAT(date_range.date, '%Y-%m-%d %H')
               ORDER BY date_range.date};
  } else {
    $query = q{SELECT date_range.date,
                      FORMAT((100*COUNT(DISTINCT(id_instrument))/?), 2) AS perc_utilisation
               FROM   date_range
               LEFT JOIN
                 (SELECT starts.id_run, starts.id_instrument,
                       ifnull(starts.start_day, date_sub(DATE(now()), interval 37 day)) as start,
                       ifnull(ends.end_day, DATE(now())) as end
                  FROM (SELECT r.id_run, id_instrument, DATE(rs.date) AS start_day
                        FROM   run r, run_status rs,run_status_dict rsd
                        WHERE  rs.id_run_status_dict = rsd.id_run_status_dict
                        AND    r.id_run = rs.id_run
                        AND    rsd.description = 'run in progress'
                        AND    rs.date > date_sub(now(), interval 37 day)) starts
                  LEFT OUTER JOIN
                    (SELECT id_run, DATE(rs.date) AS end_day
                     FROM   run_status rs, run_status_dict rsd
                     WHERE rs.id_run_status_dict = rsd.id_run_status_dict
                     AND    rsd.description in('run mirrored','run cancelled','run quarantined','data discarded','run stopped early')
                     AND    rs.date > date_sub(now(), interval 37 day)) ends
                  ON starts.id_run = ends.id_run
                  ORDER BY id_run) runs
               ON  runs.start <= date_range.date
               AND runs.end   >= date_range.date
               GROUP BY date_range.date};
  }

  $self->{'utilisation'} = [];
  my $sth = $dbh->prepare(qq{$query});
  $sth->execute($ic);
  while (my $row = $sth->fetchrow_hashref()) {
    push @{$self->{'utilisation'}}, $row;
  }

  $query = q(DROP TEMPORARY TABLE date_range);
  $dbh->do($query, {});

  return $self->{'utilisation'};
}

sub dates_all_instruments_up {
  my ( $self ) = @_;
  return $self->dates_instruments_up( 1 );
}

sub dates_instruments_up {
  my ( $self, $all ) = @_;
  my $util   = $self->util();
  my $dbh    = $util->dbh();
  my $query  = q{SELECT i.name, i.id_instrument, i_s.date AS date, isd.description AS description
    FROM   instrument_status i_s,
           instrument_status_dict isd,
           instrument i,
           instrument_format i_f
    WHERE  i_s.id_instrument = i.id_instrument
    AND    i_s.id_instrument_status_dict = isd.id_instrument_status_dict
    AND    isd.description in ('up','down', 'down for repair')
    AND    i.id_instrument_format = i_f.id_instrument_format
    };

  if ( ! $all ) {
    $query .= q{AND    i_f.model = ?
    };
  }
  $query .= q{ORDER BY name, date};

  my $inst_format = $self->{inst_format} || q{HK};

  my $ref = $all ? $dbh->selectall_arrayref( $query, {} ) : $dbh->selectall_arrayref( $query, {}, $inst_format );
  my $start_end = $dbh->selectall_arrayref(q{SELECT min(i_s.date) AS start_hour, NOW() AS end_hour FROM instrument_status i_s});
  my $name        = $ref->[0]->[0] || q[];
  my $count       = 0;
  my $start_hour  = $start_end->[0]->[0];
  my $end_hour    = $start_end->[0]->[1];
  my $instruments = {};
  my ( $current_status, $temp_hash );
  $current_status = q[];

  for my $status ( @{ $ref } ) {

    my $this_status = $status->[$FOURTH_ARRAY_ELEMENT] ;
    my $this_status_is_down = _consider_down($this_status);
    my $this_status_date = $status->[2];
    my $this_instr_name = $status->[0];

    if ( $this_instr_name ne $name ) {
      if ( $temp_hash ) {
        if ( !$temp_hash->{down} ) {
          $temp_hash->{down} = $end_hour;
        }

        $self->convert_to_datetime_objects( $temp_hash );
        push @{ $instruments->{$name} }, $temp_hash;
      }

      $count          = 0;
      $name           = $this_instr_name;
      $temp_hash      = undef;
      $current_status = q[];

    } elsif ( _consider_down($current_status) && $this_status eq 'up' ) {
      $self->convert_to_datetime_objects($temp_hash);
      push @{$instruments->{$name}}, $temp_hash;
      $temp_hash = undef;
    }

    if ( $count == 0 && $this_status_is_down ) {
      $temp_hash = {up => $start_hour, down => $this_status_date};
      $current_status = $this_status;
    } elsif ( $this_status_is_down ) {
      $temp_hash->{'down'} = $this_status_date;
      $current_status = $this_status;
    } elsif ( !$temp_hash ) {
      $current_status = $this_status;
      $temp_hash = { up => $this_status_date };
    }

    $count++;
  }
  $temp_hash->{down} = $end_hour;
  if ( $temp_hash->{up} ) {
    $self->convert_to_datetime_objects( $temp_hash );
    push @{ $instruments->{$name} }, $temp_hash;
  }

  if ( ! scalar keys %{$instruments} ) {
    croak q{<br />&nbsp;No instruments found for } . ( $all ? q{all} : $inst_format ) . q{.<br />&nbsp;If you feel this is in error, please email us.<br />};
  }

  return $instruments;
}

sub _consider_down {
  my $status = shift;
  return $status && ($status eq 'down' || $status eq 'down for repair') ? 1 : 0;
}

sub convert_to_datetime_objects {
  my ( $self, $temp_hash ) = @_;
  my ( $year,$month,$day,$hour,$min,$sec ) = $temp_hash->{up} =~ /(\d{4})-(\d{2})-(\d{2})[ ](\d{2}):(\d{2}):(\d{2})/xms;
  $temp_hash->{up} = DateTime->new( year => $year, month => $month, day => $day, hour => $hour, minute => $min, second =>$sec, time_zone => 'floating' );
  ( $year,$month,$day,$hour,$min,$sec ) = $temp_hash->{down} =~ /(\d{4})-(\d{2})-(\d{2})[ ](\d{2}):(\d{2}):(\d{2})/xms;
  $temp_hash->{down} = DateTime->new( year => $year, month => $month, day => $day, hour => $hour, minute => $min, second =>$sec, time_zone => 'floating' );
  return;
}

sub instrument_up_down {
  my ( $self, $all ) = @_;
  my $insts = $self->dates_instruments_up( $all );
  my $return = [];
  foreach my $i (sort keys %{$insts}) {
    my $temp_hash = {
      name => $i,
      statuses => [],
    };
    foreach my $up (@{$insts->{$i}}) {
      foreach my $k (qw(up down)) {
        push @{$temp_hash->{statuses}}, { date => $up->{$k}->ymd().q{ }.$up->{$k}->hms(), description => $k, };
      }
    }
    push @{$return}, $temp_hash;
  }
  return $return;
}

sub uptime_for_all_instruments {
  my ($self, $interval) = @_;

  if (!$self->{uptime_for_all_instruments}) {
    $interval ||= $DEFAULT_INSTRUMENT_UPTIME_INTERVAL;
    my $hours = $interval*$HOURS_IN_DAY;
    my @uptime;
    my $dt = DateTime->now( time_zone => 'floating' );

    $dt->set_hour(0);
    $dt->set_second(0);
    $dt->set_minute(0);

    for my $i (1..$hours) {
      my $minutes = $MINUTES_IN_HOUR;
      $dt->subtract( hours => 1 );
      my $clone = $dt->clone();
      unshift @uptime, [$clone];
    }

    my $instrument_up_regions = $self->dates_instruments_up($interval);

    for my $instrument (sort keys %{$instrument_up_regions}) {
      next if ($instrument eq 'IL28'); # we ignore IL28 (HK) as it is currently not owned by WTSI (deliberately not tested this if condition)

      for my $hour (@uptime) {

        for my $region_hash (@{$instrument_up_regions->{$instrument}}) {
          if ((! List::MoreUtils::any {$_ eq $instrument} @{$hour}) && $hour->[0] >= $region_hash->{up} && $hour->[0] <= $region_hash->{down}) {
              push @{$hour}, $instrument;
          }
        }
      }
    }

    my $ic = scalar @{$self->instrument->current_instruments()} - 1; # 1 subtracted to account for hot spare. Not happy, but not stored in database

    for my $hour (@uptime) {
      my $ic_up = scalar @{$hour} - 1;
      $hour = [$hour->[0], sprintf '%.2f', $ic_up*$PERCENTAGE/$ic];
    };

    $self->{uptime_for_all_instruments} = \@uptime;
  }
  return $self->{uptime_for_all_instruments};
}

sub average_percentage_uptime_for_day {
  my ($self, $interval) = @_;

  if (!$self->{average_percentage_uptime_for_day}) {
    my $uptime = $self->uptime_for_all_instruments($interval);
    my %days;

    for my $time (@{$uptime}) {
      push @{$days{$time->[0]->ymd()}}, $time->[1];
    }

    my $table_rows = [];
    for my $day (sort keys %days) {
      my $sum          = sum @{$days{$day}};
      my $scalar_array = scalar @{$days{$day}};
      my $perc         = sprintf '%.2f', $sum/$scalar_array;
      push @{$table_rows}, [$day, $perc];
    }

    $self->{average_percentage_uptime_for_day} = $table_rows;
  }

  return $self->{average_percentage_uptime_for_day};
}

sub instrument_percentage_uptimes {
  my ($self, $interval) = @_;

  if (!$self->{instrument_percentage_uptimes}) {
    $interval ||= $DEFAULT_INSTRUMENT_UPTIME_INTERVAL;
    my $name    = $self->instrument->name();
    my $up_periods_all_machines = $self->dates_instruments_up($interval);
    my $up_periods_this_machine = $up_periods_all_machines->{$name};
    my $today = DateTime->now( time_zone => 'floating' );
    my $dt    = $today->clone();
    my $dt2   = $today->clone();

    $dt->set_hour(0);
    $dt->set_minute(0);
    $dt->set_second(0);
    $dt2->set_hour(0);
    $dt2->set_minute(0);
    $dt2->set_second(0);
    $dt->subtract( days => $interval );

    my $seconds_uptime = $self->seconds_uptime($dt, $dt2, $up_periods_this_machine) || 0;
    my $seconds_of_last_interval_days = $dt2->subtract_datetime_absolute($dt)->in_units('seconds');
    my $percentage_of_total = sprintf '%.2f', $seconds_uptime*$PERCENTAGE/$seconds_of_last_interval_days;

    $dt = $today->clone();
    $dt->set_hour(0);
    $dt->set_minute(0);
    $dt->set_second(0);
    $dt->subtract( days => $DAYS_TO_SUBTRACT);
    $seconds_uptime = $self->seconds_uptime($dt, $dt2, $up_periods_this_machine) || 0;

    my $seconds_of_last_30_days = $dt2->subtract_datetime_absolute($dt)->in_units('seconds');
    my $percentage_of_last_30_days = sprintf '%.2f', $seconds_uptime*$PERCENTAGE/$seconds_of_last_30_days;
    $self->{instrument_percentage_uptimes} = [$percentage_of_total, $percentage_of_last_30_days]
  }

  return $self->{instrument_percentage_uptimes};
}

sub seconds_uptime {
  my ($self, $dt1, $dt2, $up_periods_this_machine) = @_;
  my $seconds_uptime;

  for my $up_period (@{$up_periods_this_machine}) {
    my $duration;
    $duration = ($up_period->{up} <= $dt1 && $up_period->{down} >= $dt2) ? $dt2->subtract_datetime_absolute($dt1)
              : ($up_period->{up} >= $dt1 && $up_period->{down} <= $dt2) ? $up_period->{down}->subtract_datetime_absolute($up_period->{up})
              : ($dt1 >= $up_period->{up} && $dt1 <= $up_period->{down}) ? $up_period->{down}->subtract_datetime_absolute($dt1)
              : ($dt2 >= $up_period->{up} && $dt2 <= $up_period->{down}) ? $dt2->subtract_datetime_absolute($up_period->{up})
              :                                                            q{}
              ;
    if ($duration) {
      $seconds_uptime += $duration->in_units('seconds');
    }
  }
  return $seconds_uptime;
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

=head2 utilisation - returns an arrayref of hashrefs in date order for last 30 days containing date (or hour) and perc_utilisation of instruments. Type is either 'hour' or 'day'

  my $aUtilisation = $oInstrumentStatus->utilisation(type);

=head2 check_order_ok - handles the rules to which instrument_statuses can be assigned via a manual entry. Croaks if not successful

  $oInstrumentStatus->check_order_ok();

=head2 request_approval - handles checking that if moving the status to 'up' from 'request approval', only the correct group can do so

  $oInstrumentStatus->request_approval();

=head2 dates_all_instruments_up - fetches from the database the status history of up and down times for all instruments, and returns a hash keyed on instrument name, each containing an array, which each element is a hash of the up periods, keys 'up' and 'down'

  my $hDatesInstrumensUp = $oInstrumentStatus->dates_all_instruments_up();

=head2 dates_instruments_up

fetches from the database the status history of up and down times for single instrument type ($self->{inst_format},
default HK), and returns a hash keyed on instrument name, each containing an array, which each element is a hash
of the up periods, keys 'up' and 'down'

optionally, you can provide a true value for $all, which will do all instruments, rather than the instrument type
found in $self->{inst_format} or default HK

  my $hDatesInstrumensUp = $oInstrumentStatus->dates_instruments_up( $all );

=head2 convert_to_datetime_objects - takes a hash with an 'up' and 'down' time, and converts them to DateTime objects

  $oInstrumentStatus->convert_to_datetime_objects({ 'up' => 'yyyy-mm-dd hh:mm:ss', 'down' => ' yyyy-mm-dd hh:mm:ss'});

=head2 uptime_for_all_instruments - returns an arrayref by hour of percentage of instruments up

  $aUptimeForAllInstruments = $oInstrumentStatus->uptime_for_all_instruments($interval);

=head2 average_percentage_uptime_for_day - returns an arrayref of arrays, each containing a date and the average percentage up-time of instruments

  $aAveragePercentageUptimeForDay = $oInstrumentStatus->average_percentage_uptime_for_day($interval);

=head2 instrument_percentage_uptimes - return an arrayref containing the 3 month (90 days) and 1 month (30 days) up-time percentage for an individual instrument

  $aInstrumentPercentageUptimes = $oInstrumentStatus->instrument_percentage_uptimes($interval);

=head2 seconds_uptime - returns the number of seconds a machine has been up over a given time period

  $iSecondsUptime = $oInstrumentStatus->seconds_uptime($oDateTime_start, $oDateTime_end, [{up => $oDateTime_up, down => $oDateTime_down},...]);

=head2 instrument_up_down - returns an arrayref of all the instruments, each of which are hashrefs containing the name and a statuses arrayref of up and down statuses 

  my $aInstrumentUpDown = $oInstrumentStatus->instrument_up_down();

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

=item Date::Calc

=item npg::model::user

=item npg::model::instrument_status_dict

=item npg::model::instrument

=item npg::model::event

=item List::Util

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
