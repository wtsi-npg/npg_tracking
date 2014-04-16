#########
# Author:        ajb
# Created:       2009-01-28
#
package npg::api::instrument_utilisation;
use strict;
use warnings;
use base qw(npg::api::base);
use Carp qw(carp croak cluck confess);
use English qw{-no_match_vars};
use DateTime;
use npg::api::instrument;
use npg::api::instrument_status;
use npg::api::run;
use Readonly;

our $VERSION = '0';

Readonly::Scalar our $SECONDS_IN_DAY     => 60*60*24;
Readonly::Scalar our $PERCENTAGE         => 100;
Readonly::Scalar our $LAST_HOUR_OF_DAY   => 23;
Readonly::Scalar our $LAST_MINUTE_OF_DAY => 59;
Readonly::Scalar our $LAST_SECOND_OF_DAY => 59;
Readonly::Scalar our $THREE_DAYS_BACK    => 3;
Readonly::Scalar our $TWO_DAYS_BACK      => 2;
Readonly::Scalar our $TWO_PM_CUTOFF      => 14;

# decode to what the model name is in the database
Readonly::Hash   our %INSTRUMENT_TYPES  => (
  ga2   => q{HK},
  hiseq => q{HiSeq},
  miseq => q{MiSeq},
);

__PACKAGE__->mk_accessors(fields(), 'instruments', 'official_insts', 'prod_insts', 'hot_spares', );

sub fields {
  return qw(
    id_instrument_utilisation
    date
    total_insts
    perc_utilisation_total_insts
    perc_uptime_total_insts
    official_insts
    perc_utilisation_official_insts
    perc_uptime_official_insts
    prod_insts
    perc_utilisation_prod_insts
    perc_uptime_prod_insts
    id_instrument_format
  );
}

sub _type {
  my ( $self, $type ) = @_;

  if ( $type ) {
    $self->{_type} = $type;
  }

  return $self->{_type};
}

sub calculate_ga2_values {
  my ( $self, @args ) = @_;
  $self->_type( q{ga2} );
  return $self->_calculate_values( @args );
}

sub calculate_hiseq_values {
  my ( $self, @args ) = @_;
  $self->_type( q{hiseq} );
  return $self->_calculate_values( @args );
}

sub calculate_miseq_values {
  my ( $self, @args ) = @_;
  $self->_type( q{miseq} );
  return $self->_calculate_values( @args );
}

sub _calculate_values {
  my ( $self, $arg_refs ) = @_;
  eval {
    # clear this object of any fields which by running it is expected to populate
    foreach my $field ( $self->fields(), 'instruments', 'official_insts', 'prod_insts', 'hot_spares' ) {
      $self->$field( undef );
    }

    print q{Looking for } . $self->_type() . qq{ instruments\n} or carp q{Looking for } . $self->_type() . qq{ instruments\n};
    my $current_instruments = $self->_current_instruments();

    # skip all the rest if there are no instruments of this type

    if ( $self->total_insts() ) {
      print qq{Determining instrument designations\n} or carp qq{Determining instrument designations\n};
      $self->determine_instrument_designations($current_instruments);

      print qq{Calculating percentage utilization\n} or carp qq{Calculating percentage utilization\n};
      $self->percentage_utilisation_of_all_instruments();

      print qq{Calculating percentage uptime\n} or carp qq{Calculating percentage uptime\n};
      $self->percentage_uptimes_of_all_instruments();

      print qq{Inserting date into record\n} or carp qq{Inserting date into record\n};
      $self->insert_date_for_record();

      print qq{Creating record\n} or carp qq{Creating record\n};
      if ( ! $arg_refs->{no_create} ) {
        $self->create('xml');
      }
    } else {
      my $msg = q{No current instruments found of type } . $self->_type() . qq{\n};
      print $msg or carp $msg;
    }
    1;
  } or do {
    croak q{Unable to calculate }  . $self->_type() . q{ values: } . $EVAL_ERROR;
  };

  return 1;
}

sub _current_instruments {
  my ( $self ) = @_;
  my $instruments = $self->api_instruments();

  my $current_insts = [];
  $self->instruments({});
  my $type = $self->_type();

  my $instrument_type_in_db = $INSTRUMENT_TYPES{$type};

  foreach my $i (@{$instruments}) {

    if ( ! $i->iscurrent()
           || $i->model() ne $instrument_type_in_db
           || ! $self->is_accepted( $i )
        ) {
      next;
    }

    $self->instruments()->{$i->id_instrument()} = {
      total_insts => 1,
    };

    if ( ! $self->id_instrument_format() ) {
      $self->id_instrument_format( $i->id_instrument_format() );
    }

    push @{$current_insts}, $i;
  }

  $self->total_insts( scalar@{$current_insts} );

  return $current_insts;
}

sub is_accepted {
  my ($self, $i) = @_;
  my $designations = $i->designations();
  foreach my $d (@{$designations}) {
    if ($d->description() eq 'Accepted') {
      return 1;
    }
  }
  return 0;
}

sub api_instruments {
  my ( $self ) = @_;

  if ( !$self->{api_instruments} ) {
    $self->{api_instruments} = npg::api::instrument->new({ util => $self->util() })->instruments();
  }

  return $self->{api_instruments};
}

sub instruments_by_type {
  my ( $self ) = @_;

  if ( !$self->{instruments_by_type} ) {
    my $ibt = {};
    foreach my $inst ( @{ $self->api_instruments() } ) {
      push @{ $ibt->{ $inst->model() } }, $inst->id_instrument();
    }
    $self->{instruments_by_type} = $ibt;
  }

  return $self->{instruments_by_type};
}

sub determine_instrument_designations {
  my ($self, $current_instruments) = @_;

  my $official_instruments = [];
  my $prod_instruments = [];

  my $hot_spare_count = 0;
  foreach my $i (@{$current_instruments}) {

    my ($r_and_d, $hot_spare);
    $self->instruments()->{$i->id_instrument()}->{name} = $i->name();
    foreach my $d (@{$i->designations()}) {
      if ($d->description() eq 'R and D' || $d->description() eq 'R&D') {
        $r_and_d++;
      }
      if ($d->description() eq 'Hot spare') {
        $hot_spare++;
        $hot_spare_count++;
      }
    }
    if (!$r_and_d)   {
      push @{$prod_instruments}, $i;
      $self->instruments()->{$i->id_instrument()}->{production}++;
    }
    if (!$hot_spare) {
      push @{$official_instruments}, $i;
      $self->instruments()->{$i->id_instrument()}->{official}++;
    }
  }

  $self->{official_insts} = scalar@{$official_instruments};
  $self->{prod_insts}     = scalar@{$prod_instruments};
  $self->{hot_spares}     = $hot_spare_count;

  return 1;
}

sub percentage_utilisation_of_all_instruments {
  my ($self) = @_;
  return $self->two_days_ago_utilisation_in_seconds();
}

sub order_runs_by_instrument_and_organise_time {
  my ( $self, $runs ) = @_;
  my $instruments = {};
  my $three_day_cutoff          = $self->two_pm_cutoff( $THREE_DAYS_BACK );
  my $two_day_cutoff            = $self->two_pm_cutoff( $TWO_DAYS_BACK );
  my $end_yesterday             = $self->end_of_yesterday_dt_object();
  my $beginning_three_days_ago  = $self->beginning_of_three_days_ago_dt_object();

  foreach my $run (@{$runs}) {
    push @{$instruments->{$run->{id_instrument}}}, $run;
  }

  foreach my $inst (sort keys %{$instruments}) {

    my $correct_type;
    foreach my $inst_by_type ( @{ $self->instruments_by_type()->{ $INSTRUMENT_TYPES{ $self->_type() } } } ) {

      if ( $inst_by_type == $inst ) {
        $correct_type++;
      }
    }
    if ( !$correct_type ) {
      $instruments->{$inst} = [];
      next;
    }

    my @temp_runs = sort { $a->{start} cmp $b->{start} } @{$instruments->{$inst}};
    my $wanted_runs_for_instrument = [];

    foreach my $run (@temp_runs) {
      my ($sy,$sm,$sd,$sh,$smin,$ss) = $run->{start} =~ /(\d{1,4})-(\d{1,2})-(\d{1,2})[ ](\d{1,2}):(\d{1,2}):(\d{1,2})/xms;
      my ($ey,$em,$ed,$eh,$emin,$es) = $run->{end}   =~ /(\d{1,4})-(\d{1,2})-(\d{1,2})[ ](\d{1,2}):(\d{1,2}):(\d{1,2})/xms;
      my $start = DateTime->new({ time_zone => 'UTC', year => $sy, month => $sm, day => $sd, hour => $sh, minute => $smin, second => $ss });
      my $end   = DateTime->new({ time_zone => 'UTC', year => $ey, month => $em, day => $ed, hour => $eh, minute => $emin, second => $es });
      my $compare_start_to_end_yesterday = $start->compare( $end_yesterday );
      my $compare_end_to_three_days_ago = $beginning_three_days_ago->compare( $end );
      next if ($compare_start_to_end_yesterday == 1 || $compare_end_to_three_days_ago == 1);
      push @{$wanted_runs_for_instrument}, $run;
      $run->{start} = $start;
      $run->{end} = $end;
    }

    $instruments->{$inst} = $wanted_runs_for_instrument;

  }

  # Now fix utilization to show following
  #
  # If run A finishes on same day as run B starts - full utilization between them
  # If run A is R1 of pair, and run B is R2 of pair - full utilization between them
  # If run A finishes after 2pm - full utilization of that day
  # If run A finishes after 2pm of day previous to run B - full utilization between them
  # Else utilization = run time during day
  foreach my $inst (sort keys %{$instruments}) {

    my @temp_runs = @{$instruments->{$inst}};

    while (@temp_runs) {
      my $run_a = $temp_runs[0];
      my $run_b = $temp_runs[1];
      shift @temp_runs;

      if ($run_b) {

        # run A stop and run B start on same day - full utilization between them
        if ($run_a->{end}->day() == $run_b->{start}->day()) {
          $run_a->{end} = $run_b->{start};
          next;
        }

        # If run A and run B are a pair - full utilization between them
        my $run_a_run_pair = $self->id_run_pair($run_a->{id_run});
        if ($run_a_run_pair && $run_a_run_pair == $run_b->{id_run}) {
          $run_a->{end} = $run_b->{start};
          next;
        }

      }

      # If end of run A after two day cutoff - full utilization to end of day (we are only scoring two days back, so it won't matter if this is actually yesterday or today early morning)
      if ($run_a->{end}->compare( $two_day_cutoff ) == 1) {
        $run_a->{end}->set_hour($LAST_HOUR_OF_DAY);
        $run_a->{end}->set_minute($LAST_MINUTE_OF_DAY);
        $run_a->{end}->set_second($LAST_SECOND_OF_DAY);
        next;
      }

      if ($run_b) {

        # If end of run A after 3 day cutoff and $run_b loaded two days ago - full utilization between
        if ($run_a->{end}->compare( $three_day_cutoff ) == 1) {
          if ($run_b->{start}->day() == $two_day_cutoff->day()) {
            $run_b->{start} = $run_a->{end};
            next;
          }
        }

      }

    }
  }

  my $return_runs = [];
  foreach my $inst (sort keys %{$instruments}) {
    foreach my $run (@{$instruments->{$inst}}) {
      my ($sy,$sm,$sd,$sh,$smin,$ss) = $run->{start} =~ /(\d{1,4})-(\d{1,2})-(\d{1,2})[T](\d{1,2}):(\d{1,2}):(\d{1,2})/xms;
      my ($ey,$em,$ed,$eh,$emin,$es) = $run->{end}   =~ /(\d{1,4})-(\d{1,2})-(\d{1,2})[T](\d{1,2}):(\d{1,2}):(\d{1,2})/xms;
      $sm = sprintf '%02d', $sm;
      $em = sprintf '%02d', $em;
      $sd = sprintf '%02d', $sd;
      $ed = sprintf '%02d', $ed;

      my $string = $sy.$sm.$sd;
      $run->{start_number} = $string.$sh.$smin.$ss;
      $string = $ey.$em.$ed;
      $run->{end_number} = $string.$eh.$emin.$es;

      push @{$return_runs}, $run;
    }
  }

  return $return_runs;
}
##use critic

sub two_days_ago_utilisation_in_seconds {
  my ( $self ) = @_;
  my $runs = $self->recent_running_runs();

  $runs = $self->order_runs_by_instrument_and_organise_time( $runs );

  my $dt = $self->two_days_ago_datetime_object();
  my $y = $dt->year();
  my $m = $dt->month();
  my $d = $dt->day();
  my $beginning_of_two_days_ago = $self->beginning_of_two_days_ago_dt_object();
  my $end_of_two_days_ago       = $self->end_of_two_days_ago_dt_object();

  $m = sprintf '%02d', $m;
  $d = sprintf '%02d', $d;
  my $string = $y.$m.$d;

  my $two_days_ago_start_num = $string.q{000000};
  my $two_days_ago_end_num   = $string.q{235959};
  my $instruments = $self->instruments();

  my $three_days_ago_cutoff = $self->two_pm_cutoff( $THREE_DAYS_BACK );
  my $two_days_ago_cutoff   = $self->two_pm_cutoff( $TWO_DAYS_BACK   );

  foreach my $run (@{$runs}) {

    ##########
    # if the instrument isn't to be included, then skip
    if (!$instruments->{$run->{id_instrument}}) { next; }

    ##########
    # if the instrument already has enough seconds for a full days utilization, skip
    if (!$instruments->{$run->{id_instrument}}->{seconds_used} >= $SECONDS_IN_DAY) { next; }

    my $start = $run->{start};
    my $end   = $run->{end};
    my $sy    = sprintf '%04d', $start->year();
    my $ey    = sprintf '%04d', $end->year();
    my $sm    = sprintf '%02d', $start->month();
    my $em    = sprintf '%02d', $end->month();
    my $sd    = sprintf '%02d', $start->day();
    my $ed    = sprintf '%02d', $end->day();
    my $sh    = sprintf '%02d', $start->hour();
    my $eh    = sprintf '%02d', $end->hour();
    my $smin  = sprintf '%02d', $start->minute();
    my $emin  = sprintf '%02d', $end->minute();
    my $ss    = sprintf '%02d', $start->second();
    my $es    = sprintf '%02d', $end->second();

    $string = $sy.$sm.$sd;
    my $start_number = $string.$sh.$smin.$ss;
    $string = $ey.$em.$ed;
    my $end_number   = $string.$eh.$emin.$es;
    ###########
    # if starts after two_days_ago, or ends before two_days_ago, skip
    if ($end_number < $two_days_ago_start_num || $two_days_ago_end_num < $start_number) {
      next;
    }

    ##########
    # if run starts before two_days_ago and ends after two_days_ago, then util is whole day, and then move on
    if ($end_number > $two_days_ago_end_num && $two_days_ago_start_num > $start_number) {

      $instruments->{$run->{id_instrument}}->{seconds_used} = $SECONDS_IN_DAY;
      next;

    }

    ##########
    # work out portion of day in secs if the run overlaps the start or end of two_days_ago
    if ($end_number > $two_days_ago_start_num && $start_number < $two_days_ago_start_num) {

      $instruments->{$run->{id_instrument}}->{seconds_used} += $end->subtract_datetime_absolute($beginning_of_two_days_ago)->seconds();

    } elsif ($start_number < $two_days_ago_end_num && $end_number > $two_days_ago_end_num) {

      $instruments->{$run->{id_instrument}}->{seconds_used} += $end_of_two_days_ago->subtract_datetime_absolute($start)->seconds();

    }
  }

  my ($total,$official,$production);
  foreach my $i (sort keys %{$instruments}) {

    if ($instruments->{$i}->{seconds_used}) {

      if ($instruments->{$i}->{seconds_used} > $SECONDS_IN_DAY) {
        $instruments->{$i}->{seconds_used} = $SECONDS_IN_DAY;
      }

      $instruments->{$i}->{perc_used} = ($instruments->{$i}->{seconds_used}) * $PERCENTAGE / $SECONDS_IN_DAY;

    } else {

      $instruments->{$i}->{perc_used} = 0;

    }

    $total += $instruments->{$i}->{perc_used};

    if ( $instruments->{$i}->{official}   ) { $official   += $instruments->{$i}->{perc_used}; }
    if ( $instruments->{$i}->{production} ) { $production += $instruments->{$i}->{perc_used}; }

  }

  if ( $self->total_insts() )    { $self->perc_utilisation_total_insts(    sprintf '%.2f', ( $total       / $self->total_insts()    ) ) };
  if ( $self->official_insts() ) { $self->perc_utilisation_official_insts( sprintf '%.2f', ( $total       / $self->official_insts() ) ) };
  if ( $self->prod_insts() )     { $self->perc_utilisation_prod_insts(     sprintf '%.2f', ( $production  / $self->prod_insts()     ) ) };

  return 1;
}

sub recent_running_runs {
  my ($self) = @_;

  if (!$self->{recent_running_runs}) {

    $self->{recent_running_runs} = npg::api::run->new({ util => $self->util() })->recent_running_runs();

  }

  return $self->{recent_running_runs};
}

sub id_run_pair {
  my ($self, $id_run) = @_;
  return npg::api::run->new({ util => $self->util(), id_run => $id_run })->id_run_pair();
}

sub yesterday_datetime_object {
  my ($self) = @_;
  if(!$self->{yesterday_datetime_object}) {
    $self->{yesterday_datetime_object} = DateTime->now()->subtract( days => 1 );
  }
  return $self->{yesterday_datetime_object};
}

sub beginning_of_yesterday_dt_object {
  my ($self) = @_;
  if(!$self->{beginning_of_yesterday_dt_object}) {
    my $dt = $self->yesterday_datetime_object();
    my $y  = $dt->year();
    my $m  = $dt->month();
    my $d  = $dt->day();
    $self->{beginning_of_yesterday_dt_object} = DateTime->new({ time_zone => 'UTC', year => $y, month => $m, day => $d });
  }
  return $self->{beginning_of_yesterday_dt_object};
}

sub end_of_yesterday_dt_object {
  my ($self) = @_;
  if(!$self->{end_of_yesterday_dt_object}) {
    my $dt = $self->yesterday_datetime_object();
    my $y  = $dt->year();
    my $m  = $dt->month();
    my $d  = $dt->day();
    $self->{end_of_yesterday_dt_object} = DateTime->new({ time_zone => 'UTC', year => $y, month => $m, day => $d, hour => $LAST_HOUR_OF_DAY, minute => $LAST_MINUTE_OF_DAY, second => $LAST_MINUTE_OF_DAY });
  }
  return $self->{end_of_yesterday_dt_object};
}

sub two_days_ago_datetime_object {
  my ($self) = @_;
  if(!$self->{two_days_ago_datetime_object}) {
    $self->{two_days_ago_datetime_object} = DateTime->now()->subtract( days => 2 );
  }
  return $self->{two_days_ago_datetime_object};
}

sub beginning_of_two_days_ago_dt_object {
  my ($self) = @_;
  if(!$self->{beginning_of_two_days_ago_dt_object}) {
    my $dt = $self->two_days_ago_datetime_object();
    my $y  = $dt->year();
    my $m  = $dt->month();
    my $d  = $dt->day();
    $self->{beginning_of_two_days_ago_dt_object} = DateTime->new({ time_zone => 'UTC', year => $y, month => $m, day => $d });
  }
  return $self->{beginning_of_two_days_ago_dt_object};
}

sub end_of_two_days_ago_dt_object {
  my ($self) = @_;
  if(!$self->{end_of_two_days_ago_dt_object}) {
    my $dt = $self->two_days_ago_datetime_object();
    my $y  = $dt->year();
    my $m  = $dt->month();
    my $d  = $dt->day();
    $self->{end_of_two_days_ago_dt_object} = DateTime->new({ time_zone => 'UTC', year => $y, month => $m, day => $d, hour => $LAST_HOUR_OF_DAY, minute => $LAST_MINUTE_OF_DAY, second => $LAST_MINUTE_OF_DAY });
  }
  return $self->{end_of_two_days_ago_dt_object};
}

sub two_pm_cutoff {
  my ($self,$day) = @_;
  my $dt = $day == 2                ? $self->two_days_ago_datetime_object()
         : $day == $THREE_DAYS_BACK ? $self->three_days_ago_datetime_object()
         :                            $self->yesterday_datetime_object()
         ;
  my $y  = $dt->year();
  my $m  = $dt->month();
  my $d  = $dt->day();
  return DateTime->new({ time_zone => 'UTC', year => $y, month => $m, day => $d, hour => $TWO_PM_CUTOFF, minute => 0, second => 0 });
}

sub three_days_ago_datetime_object {
  my ($self) = @_;
  if(!$self->{three_days_ago_datetime_object}) {
    $self->{three_days_ago_datetime_object} = DateTime->now()->subtract( days => $THREE_DAYS_BACK );
  }
  return $self->{three_days_ago_datetime_object};
}

sub beginning_of_three_days_ago_dt_object {
  my ($self) = @_;
  if(!$self->{beginning_of_three_days_ago_dt_object}) {
    my $dt = $self->three_days_ago_datetime_object();
    my $y  = $dt->year();
    my $m  = $dt->month();
    my $d  = $dt->day();
    $self->{beginning_of_three_days_ago_dt_object} = DateTime->new({ time_zone => 'UTC', year => $y, month => $m, day => $d });
  }
  return $self->{beginning_of_three_days_ago_dt_object};
}

sub end_of_three_days_ago_dt_object {
  my ($self) = @_;
  if(!$self->{end_of_three_days_ago_dt_object}) {
    my $dt = $self->three_days_ago_datetime_object();
    my $y  = $dt->year();
    my $m  = $dt->month();
    my $d  = $dt->day();
    $self->{end_of_three_days_ago_dt_object} = DateTime->new({ time_zone => 'UTC', year => $y, month => $m, day => $d, hour => $LAST_HOUR_OF_DAY, minute => $LAST_MINUTE_OF_DAY, second => $LAST_MINUTE_OF_DAY });
  }
  return $self->{end_of_three_days_ago_dt_object};
}

sub percentage_uptimes_of_all_instruments {
  my ( $self, $type ) = @_;
  my $insts = $self->instruments();
  my $uptime = $self->two_days_ago_uptime();
  my ($total,$official,$production);
  foreach my $i (sort keys %{$insts}) {
    $uptime->{$insts->{$i}{name}}->{percentage} ||= 0;
    $total += $uptime->{$insts->{$i}{name}}->{percentage};
    if ($insts->{$i}{official}) { $official += $uptime->{$insts->{$i}{name}}->{percentage} };
    if ($insts->{$i}{production}) { $production += $uptime->{$insts->{$i}{name}}->{percentage} };
  }

  if ($self->total_insts())    { $self->perc_uptime_total_insts(sprintf '%.2f', ($total/$self->total_insts())) };
  if ($self->official_insts()) { $self->perc_uptime_official_insts(sprintf '%.2f', ($total/$self->official_insts())) };
  if ($self->prod_insts())     { $self->perc_uptime_prod_insts(sprintf '%.2f', ($production/$self->prod_insts())) };

  return 1;
}

sub two_days_ago_uptime {
  my ($self) = @_;
  if (!$self->{two_days_ago_uptime}) {
    my $uptime_per_instrument = $self->two_days_ago_uptime_in_seconds();
    foreach my $name (sort keys %{$uptime_per_instrument}) {
      $uptime_per_instrument->{$name}->{percentage} = sprintf '%.2f', ($uptime_per_instrument->{$name}->{seconds} * $PERCENTAGE / $SECONDS_IN_DAY);
    }
    $self->{two_days_ago_uptime} = $uptime_per_instrument
  }
  return $self->{two_days_ago_uptime};
}

sub two_days_ago_uptime_in_seconds {
  my ($self) = @_;
  if (!$self->{two_days_ago_uptime_in_seconds}) {
    my $instruments = $self->instrument_status_object()->uptimes();

    my $dt = $self->two_days_ago_datetime_object();
    my $y = $dt->year();
    my $m = $dt->month();
    my $d = $dt->day();
    my $beginning_of_two_days_ago = $self->beginning_of_two_days_ago_dt_object();
    my $end_of_two_days_ago       = $self->end_of_two_days_ago_dt_object();

    $m = sprintf '%02d', $m;
    $d = sprintf '%02d', $d;
    my $string = $y.$m.$d;

    my $two_days_ago_start_num = $string.q{000000};
    my $two_days_ago_end_num   = $string.q{235959};

    my $seconds_per_instrument = {};

    foreach my $i (@{$instruments}) {
      my $name = $i->{name};
      $seconds_per_instrument->{$name}{seconds} = 0;
      my @statuses = reverse @{$i->{statuses}};
      my $current_state;
      my ($last_up, $last_down, $last_dt_object);
      foreach my $s (@statuses) {
        my $date = $s->{date};
        my $state = $s->{description};
        $current_state ||= $state;
        my ($sy,$sm,$sd,$sh,$smin,$ss) = $date =~ /(\d{1,4})-(\d{1,2})-(\d{1,2})[ ](\d{1,2}):(\d{1,2}):(\d{1,2})/xms;
        $sm = sprintf '%02d', $sm;
        $sd = sprintf '%02d', $sd;
        $sh = sprintf '%02d', $sh;
        $smin = sprintf '%02d', $smin;
        $ss = sprintf '%02d', $ss;
        my $current_dt_object = DateTime->new({ time_zone => 'UTC', year => $sy, month => $sm, day => $sd, hour => $sh, minute => $smin, second => $ss });
        my $s_string = $sy.$sm.$sd.$sh.$smin.$ss;

        if ($s_string < $two_days_ago_start_num) { # this status date is before two_days_ago
          if ($state eq 'up') { # only worry if this state is up
            if ($last_down) { ## no critic (ControlStructures::ProhibitDeepNests)
              if ($last_down > $two_days_ago_end_num) { ## no critic (ControlStructures::ProhibitDeepNests)
                # this implies it was up all day
                $seconds_per_instrument->{$name}{seconds} = $SECONDS_IN_DAY;
              } else { # only up part of the day, from midnight
                $seconds_per_instrument->{$name}{seconds} += $last_dt_object->subtract_datetime_absolute($beginning_of_two_days_ago)->seconds();
              }
            } else {
              if (!$last_up || $last_up > $two_days_ago_end_num) { ## no critic (ControlStructures::ProhibitDeepNests)
                # this implies it was up all day
                $seconds_per_instrument->{$name}{seconds} = $SECONDS_IN_DAY;
              } else { # whilst still up, the rest of the day would already have been counted
                $seconds_per_instrument->{$name}{seconds} += $last_dt_object->subtract_datetime_absolute($beginning_of_two_days_ago)->seconds();
              }
            }
          }
          last;
        } elsif ($s_string > $two_days_ago_end_num) { # this status date is after two_days_ago, just set the date and the state
          $current_state = $state;
          if ($state eq 'down' || $state eq 'down for repair') {
            $last_down = $s_string;
            $last_up = undef;
          } else {
            $last_up = $s_string;
            $last_down = undef;
          }
        } else { # the date is during two_days_ago
          if ($state eq 'down' && $current_state eq 'up') { ## no critic (ControlStructures::ProhibitCascadingIfElse)
            # if we are about to enter a period (going backwards) where it is up 
            $current_state = 'down';
            $last_down = $s_string;
            $last_up = undef;
          } elsif ($state eq 'up' && ($current_state eq 'down' || $current_state eq 'down for repair')) { # if we are about to enter a period (going backwards) where it is down
            $current_state = 'up';
            my $seconds_down_til_end_of_day = 0;
            if ($last_down < $two_days_ago_end_num) { ## no critic (ControlStructures::ProhibitDeepNests)
              # accounts for where end part of the day has already been accounted for 
              $seconds_down_til_end_of_day += $end_of_two_days_ago->subtract_datetime_absolute($last_dt_object)->seconds();
            }
            $seconds_per_instrument->{$name}{seconds} += $end_of_two_days_ago->subtract_datetime_absolute($current_dt_object)->seconds();
            $seconds_per_instrument->{$name}{seconds} -= $seconds_down_til_end_of_day;
            $last_down = undef;
            $last_up = $s_string;
          } elsif ($state eq 'up') { # if we have had two statuses of up (going backwards) (possible, but unlikely)
            $seconds_per_instrument->{$name}{seconds} += $last_dt_object->subtract_datetime_absolute($current_dt_object)->seconds();
            my $seconds_down_til_end_of_day = 0;
            if ($last_up < $two_days_ago_end_num) { ## no critic (ControlStructures::ProhibitDeepNests)
              $seconds_down_til_end_of_day += $end_of_two_days_ago->subtract_datetime_absolute($last_dt_object)->seconds();
            }
            $seconds_per_instrument->{$name}{seconds} -= $seconds_down_til_end_of_day;
            $last_up = $s_string;
          } elsif ($state eq 'down' || $state eq 'down for repair') { # if we have had a second period where it has been down (possible, but unlikely)
            $last_down = $s_string;
          }
        }
        $last_dt_object = $current_dt_object;
      }
    }
    $self->{two_days_ago_uptime_in_seconds} = $seconds_per_instrument;
  }
  return $self->{two_days_ago_uptime_in_seconds};
}

sub instrument_status_object {
  my ($self) = @_;
  if(!$self->{instrument_status_object}) {
    $self->{instrument_status_object} = npg::api::instrument_status->new({util => $self->util()});
  }
  return $self->{instrument_status_object};
}

sub insert_date_for_record {
  my ($self) = @_;
  $self->date( $self->beginning_of_two_days_ago_dt_object()->ymd() . q{ } . $self->beginning_of_two_days_ago_dt_object()->hms() );
  return 1;
}

1;
__END__

=head1 NAME

npg::api::instrument_utilisation - An interface onto npg.instrument_utilisation

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - constructor inherited from npg::api::base

  Takes optional util.

  my $oInstrumentUtilisation = npg::api::instrument_utilisation->new();

  my $oInstrumentUtilisation = npg::api::instrument_utilisation->new({
    'id_instrument_utilisation' => $iIdInstrumentUtilisation,
    'util'          => $oUtil,
  });


  my $oInstrumentUtilisation = npg::api::instrument_utilisation->new({
    <fields> => <values>.
  });
  $oInstrumentUtilisation->create();

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::api::<pkg>->fields();

=head2 id_instrument_utilisation - Get/set accessor: primary key of this object

  my $iIdInstrumentUtilisation = $oInstrumentUtilisation->id_instrument_utilisation();
  $oInstrumentUtilisation->id_instrument_utilisation($i);

=head2 date - Get/set accessor: date of this utilization

  my $sDate = $oInstrumentUtilisation->date();
  $oInstrumentUtilisation->date($s);

=head2 total_insts - Get/set accessor: total_insts of this utilization

  my $sTotalInsts = $oInstrumentUtilisation->total_insts();
  $oInstrumentUtilisation->total_insts($s);

=head2 perc_utilisation_total_insts - Get/set accessor: perc_utilisation_total_insts of this utilization

  my $sPercUtilisationTotalInsts = $oInstrumentUtilisation->perc_utilisation_total_insts();
  $oInstrumentUtilisation->perc_utilisation_total_insts($s);

=head2 perc_uptime_total_insts - Get/set accessor: perc_uptime_total_insts of this utilization

  my $sPercUptimeTotalInsts = $oInstrumentUtilisation->perc_uptime_total_insts();
  $oInstrumentUtilisation->perc_uptime_total_insts($s);

=head2 official_insts - Get/set accessor: official_insts of this utilization

  my $sOfficialInsts = $oInstrumentUtilisation->official_insts();
  $oInstrumentUtilisation->official_insts($s);

=head2 perc_utilisation_official_insts - Get/set accessor: perc_utilisation_official_insts of this utilization

  my $sPercUtilisationOfficialInsts = $oInstrumentUtilisation->perc_utilisation_official_insts();
  $oInstrumentUtilisation->perc_utilisation_official_insts($s);

=head2 perc_uptime_official_insts - Get/set accessor: perc_uptime_official_insts of this utilization

  my $sPercUptimeOfficialInsts = $oInstrumentUtilisation->perc_uptime_official_insts();
  $oInstrumentUtilisation->perc_uptime_official_insts($s);

=head2 prod_insts - Get/set accessor: prod_insts of this utilization

  my $sProdInsts = $oInstrumentUtilisation->prod_insts();
  $oInstrumentUtilisation->prod_insts($s);

=head2 perc_utilisation_prod_insts - Get/set accessor: perc_utilisation_prod_insts of this utilization

  my $sPercUtilisationProdInsts = $oInstrumentUtilisation->perc_utilisation_prod_insts();
  $oInstrumentUtilisation->perc_utilisation_prod_insts($s);

=head2 perc_uptime_prod_insts - Get/set accessor: perc_uptime_prod_insts of this utilization

  my $sPercUptimeProdInsts = $oInstrumentUtilisation->perc_uptime_prod_insts();
  $oInstrumentUtilisation->perc_uptime_prod_insts($s);

=head2 calculate_ga2_values - runs through and calculates all the percentage up-time and utilization for the previous day for GA2 machines

  eval { $oInstrumentUtilisation->calculate_ga2_values(); } or do { croak $EVAL_ERROR; };

=head2 calculate_hiseq_values - runs through and calculates all the percentage up-time and utilization for the previous day for HiSeq machines

  eval { $oInstrumentUtilisation->calculate_hiseq_values(); } or do { croak $EVAL_ERROR; };

=head2 calculate_miseq_values - runs through and calculates all the percentage up-time and utilization for the previous day for MiSeq machines

  eval { $oInstrumentUtilisation->calculate_miseq_values(); } or do { croak $EVAL_ERROR; };

=head2 current_ga2_instruments - fetches list of instruments and determines if they are current accepted

=head2 is_accepted - determines from an instruments designations if it has been accepted for Sanger use

=head2 api_instruments - returns and caches an npg::api::instrument object

=head2 instruments_by_type - returns a hash keyed by instrument model, with values arrays of instrument ids

=head2 determine_instrument_designations - goes through all the instruments, and determines if they are production, R&D or hot spare

=head2 percentage_utilisation_of_all_instruments  - returns $self->two_days_agos_utilisation_in_seconds()

=head2 order_runs_by_instrument_and_organise_time - sorts the runs by instrument and time, then determines where utilization is longer than run time

=head2 two_days_ago_utilisation_in_seconds - calculates the utilization in seconds of the instruments two_days_ago and stores the percentage utilization

=head2 recent_running_runs - gets a list of the recent runs from NPG with which to determine utilization from

=head2 yesterday_datetime_object - returns and caches a DateTime object which represents a time from yesterday

=head2 beginning_of_yesterday_dt_object - returns and caches a DateTime object which represents yesterday at midnight

=head2 end_of_yesterday_dt_object - returns and caches a DateTime object which represents yesterday at 23:59:59

=head2 two_days_ago_datetime_object - returns and caches a DateTime object which represents a time from two_days_ago

=head2 beginning_of_two_days_ago_dt_object - returns and caches a DateTime object which represents two_days_ago at midnight

=head2 end_of_two_days_ago_dt_object - returns and caches a DateTime object which represents two_days_ago at 23:59:59

=head2 three_days_ago_datetime_object - returns and caches a DateTime object which represents a time from three_days_ago

=head2 beginning_of_three_days_ago_dt_object - returns and caches a DateTime object which represents three_days_ago at midnight

=head2 end_of_three_days_ago_dt_object - returns and caches a DateTime object which represents three_days_ago at 23:59:59

=head2 two_pm_cutoff - returns a DateTime object for the cutoff time that an instrument can be expected to finish a run and be turned around that day, takes a numerical argument 1/2/3 as to the number of days back the object should be

=head2 percentage_uptimes_of_all_instruments - calculates and stores the percentage up-time of all instruments two_days_ago

=head2 two_days_ago_uptime - calculates the percentage up-time per instrument two_days_ago

=head2 two_days_ago_uptime_in_seconds - calculates the up-time in seconds per instrument two_days_ago

=head2 instrument_status_object - returns and stores an npg::api::instrument_status object

=head2 insert_date_for_record - inserts the date two_days_ago into the correct field name space which will be used for this record

=head2 id_run_pair - gets the id_run_pair for a run, in order to determine if the run is preceded by its first end, or succeeded by its second end

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

npg::api::base

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown, E<lt>ajb@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2009 GRL, by Andy Brown

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
