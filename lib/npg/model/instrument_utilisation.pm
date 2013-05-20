#########
# Author:        ajb
# Maintainer:    $Author: js10 $
# Created:       2009-01-21
# Last Modified: $Date: 2012-03-20 12:02:08 +0000 (Tue, 20 Mar 2012) $
# Id:            $Id: instrument_utilisation.pm 15357 2012-03-20 12:02:08Z js10 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg/model/instrument_utilisation.pm $
#
package npg::model::instrument_utilisation;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::instrument;
use npg::model::instrument_status;
use npg::model::instrument_status_dict;
use npg::model::instrument_designation;
use npg::model::designation;
use npg::util::image::image_map;
use npg::util::image::merge;
use DateTime;
use Readonly;

Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 15357 $ =~ /(\d+)/smx; $r; };

Readonly::Scalar our $PERCENTAGE    => 100;
Readonly::Scalar our $DATE          => 0;
Readonly::Scalar our $TOTAL_PERC    => 1;
Readonly::Scalar our $OFFICIAL_PERC => 2;
Readonly::Scalar our $PROD_PERC     => 3;
Readonly::Scalar our $DEFAULT_INSTRUMENT_UPTIME_INTERVAL => 90;
Readonly::Scalar our $THIRTY_DAYS          => 30;
Readonly::Scalar our $DEFAULT_GANTT_WIDTH  => 1_000;
Readonly::Scalar our $DEFAULT_GANTT_HEIGHT => 400;
Readonly::Scalar our $DEFAULT_GANTT_Y_TICK => 9;

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_all();

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

sub init {
  my $self = shift;

  if($self->{'date'} &&
     !$self->{'id_instrument_utilisation'}) {
    my $field_string = join q{,}, $self->fields();
    my $query = q(SELECT id_instrument_utilisation
                  FROM   instrument_utilisation
                  WHERE  date = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->date());

    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{'id_instrument_utilisation'} = $ref->[0]->[0];
      $self->read();
    }
  }
  return 1;
}

sub default_num_days {
  my $self = shift;
  return $THIRTY_DAYS;
}


sub last_30_days {

  my ($self, $insts) = @_;
  carp q[npg::model::instrument_utilisation->last_30_days() is deprecated, use npg::model::instrument_utilisation->last_X_days() instead];
  if (!$insts) {
    croak 'no instrument grouping provided';
  }

  return $self->last_x_days($insts);
}

sub last_x_days {

  my ( $self, $arg_refs ) = @_;
  my $insts = $arg_refs->{insts};
  my $num_days = $arg_refs->{num_days};

  my $instrument_format = $arg_refs->{instrument_format} || q{HK};
  $instrument_format = $self->sanitise_input( $instrument_format );

  if (!$insts) {
    croak 'no instrument grouping provided';
  }

  if (!$num_days) {$num_days = $THIRTY_DAYS;}

  my $utilisation_column = 'iu.perc_utilisation_'.$insts;
  my $uptime_column = 'iu.perc_uptime_'.$insts;
  my $q = qq{SELECT iu.date, $insts, $utilisation_column, $uptime_column
             FROM   instrument_utilisation iu,
                    instrument_format instf
             WHERE  instf.id_instrument_format = iu.id_instrument_format
             AND    instf.model = ?
             ORDER BY date DESC LIMIT $num_days};

  my $dbh = $self->util->dbh();
  my @data;
  eval {
    @data = reverse @{$dbh->selectall_arrayref($q, {}, $instrument_format)}; # reverse, so that when read will be in ascending date order
    1;
  } or do {
    croak $EVAL_ERROR;
  };
  return \@data;
}

sub table_data_total_insts {
  my ($self, $num_days, $instrument_format) = @_;
  if (!$num_days) {$num_days = $THIRTY_DAYS;}
  return $self->last_x_days({
    insts => 'total_insts',
    num_days => $num_days,
    instrument_format => $instrument_format,
  });
}

sub table_data_official_insts {
  my ($self, $num_days, $instrument_format) = @_;
  if (!$num_days) {$num_days = $THIRTY_DAYS;}
  return $self->last_x_days({
    insts => 'official_insts',
    num_days => $num_days,
    instrument_format => $instrument_format,
  });
}

sub table_data_prod_insts {
  my ($self, $num_days, $instrument_format) = @_;
  if (!$num_days) {$num_days = $THIRTY_DAYS;}
  return $self->last_x_days({
    insts => 'prod_insts',
    num_days => $num_days,
    instrument_format => $instrument_format,
  });
}

sub graph_data {
  my ($self, $type, $num_days, $instrument_format) = @_;

  if (!$num_days) {$num_days = $THIRTY_DAYS;}
  my $types;
  if ($type eq 'utilisation_uptime') {
    @{$types} = split /_/xms, $type;
  } else {
    $types = [$type];
  }
  my $data;
  foreach my $t (@{$types}) {
    push @{$data}, $self->obtain_graph_data($t, $num_days, $instrument_format);
  }
  if (scalar@{$data} == 1) {
    return $data->[0];
  }
  my $utilisation_data = $data->[0];
  my $uptime_data = $data->[1];
  my $i = 0;
  my $return = [];
  foreach my $utilisation (@{$utilisation_data}) {
    if ($utilisation->[$DATE] ne $uptime_data->[$i]->[$DATE]) { croak q{dates do not match, unable to calculate utilisation as a percentage of up-time}; }
    my $temp = [];

    my $total_perc    = $uptime_data->[$i]->[$TOTAL_PERC]    ? $utilisation->[$TOTAL_PERC] * $PERCENTAGE / $uptime_data->[$i]->[$TOTAL_PERC]
                      :                                        '0.00'
                      ;

    my $official_perc = $uptime_data->[$i]->[$OFFICIAL_PERC] ? $utilisation->[$OFFICIAL_PERC] * $PERCENTAGE / $uptime_data->[$i]->[$OFFICIAL_PERC]
                      :                                        '0.00'
                      ;

    my $prod_perc     = $uptime_data->[$i]->[$PROD_PERC]     ? $utilisation->[$PROD_PERC] * $PERCENTAGE / $uptime_data->[$i]->[$PROD_PERC]
                      :                                        '0.00'
                      ;

    push @{$temp}, $utilisation->[$DATE];
    push @{$temp}, sprintf '%.2f', $total_perc;
    push @{$temp}, sprintf '%.2f', $official_perc;
    push @{$temp}, sprintf '%.2f', $prod_perc;
    push @{$return}, $temp;
    $i++;
  }
  return $return;
}

sub obtain_graph_data {

  my ( $self, $type, $num_days, $instrument_format ) = @_;
  if ( !$num_days ) {
    $num_days = $THIRTY_DAYS;
  }

  my $total     = q{iu.perc_} . $type . q{_total_insts};
  my $official  = q{iu.perc_} . $type . q{_official_insts};
  my $prod      = q{iu.perc_} . $type . q{_prod_insts};
  my $q = qq{SELECT iu.date, $total, $official, $prod
             FROM   instrument_utilisation iu,
                    instrument_format instf
             WHERE iu.id_instrument_format = instf.id_instrument_format
             AND   instf.model = ?
             ORDER BY date DESC LIMIT $num_days};
  my $dbh = $self->util->dbh();
  my @data;
  eval {
    @data = reverse @{$dbh->selectall_arrayref($q, {}, $instrument_format)}; # reverse, so that when read will be in ascending date order
    1;
  } or do {
    croak $EVAL_ERROR;
  };
  return \@data;
}

sub create {
  my ($self, @args) = @_;
  $self->SUPER::create(@args);
  $self->read();
  return 1;
}

sub gantt_map {
  my ($self, $chart_id, $url) = @_;
  my $refs = $self->gantt_run_timeline_png(1);
  my $image_map = npg::util::image::image_map->new();
  my $data = [];

  foreach my $gantt_box (@{$refs->{gantt_boxes}}) {
    push @{$data}, $gantt_box;
  }

  my $map = $image_map->render_map({
    data => $data,
    image_url => $ENV{SCRIPT_NAME}.$url,
    id => $chart_id,
  });

  return $map;
}

sub gantt_run_timeline_png {
  my ( $self, $ref_points, $instrument_model ) = @_;
  my $stripe_across_for_gantt = $self->_run_time_stripe_across_for_gantt( $instrument_model );
  my $merge = npg::util::image::merge->new();
  my $arg_refs = {
    format        => 'gantt_chart_vertical',
    x_label       => 'Instrument',
    y_label       => 'Date',
    y_tick_number => $DEFAULT_GANTT_Y_TICK,
    y_max_value   => $stripe_across_for_gantt->{y_max_value},
    y_min_value   => $stripe_across_for_gantt->{y_min_value},
    x_axis        => $stripe_across_for_gantt->{instruments},
    data_points   => $stripe_across_for_gantt->{data},
    height        => $DEFAULT_GANTT_HEIGHT,
    width         => $DEFAULT_GANTT_WIDTH,
    borderclrs    => [qw{lgray}],
    y_number_format => $stripe_across_for_gantt->{code},
    get_anno_refs => 1,
    colour_of_block => q{green},
  };

  my $png;
  eval { $png = $merge->merge_images($arg_refs); } or do { croak qq{Unable to create gantt_chart_png:\n\n}.$EVAL_ERROR; };

  if ($ref_points) {
    my $image_map = npg::util::image::image_map->new();
    my $href = {};
    $href->{gantt_boxes} = $image_map->process_instrument_gantt_values({additional_info => q{RUNNING}, data_points => $merge->gantt_refs(), data_values => $stripe_across_for_gantt->{data}, convert => $stripe_across_for_gantt->{code}});
    return $href;
  }

  return $png;
}

sub instruments {
  my ($self) = @_;
  return npg::model::instrument->new({util => $self->util()})->instruments();
}

sub _run_time_stripe_across_for_gantt {
  my ( $self, $instrument_model ) = @_;
  $instrument_model = $instrument_model || $self->{inst_format} || q{HK};
  my $instrument_run_times = $self->_instrument_run_times( q{}, $instrument_model);

  foreach my $i (sort {$a <=> $b} keys %{$instrument_run_times}) {
    my $inst_object = npg::model::instrument->new({
      util => $self->util(), id_instrument => $i,
    });
    if ( ! $inst_object->iscurrent()
         ||
         $inst_object->model() ne $instrument_model
       ) {
      delete $instrument_run_times->{$i};
    }

  }

  my $all_insts = $self->instruments();
  my $instruments = [];
  my $stripe_indices = {};
  my $stripe_index = 0;
  foreach my $inst ( @{ $all_insts } ) {
    if ( ! $inst->iscurrent()
         ||
         $inst->model() ne $instrument_model
       ) {
      next;
    }
    push @{$instruments}, $inst->name();
    $stripe_indices->{$inst->id_instrument()} = $stripe_index;
    $stripe_index++;
  }

  my $max_number_of_changes = 0;
  my $stripe = [];
  my $dt = DateTime->now();
  my $dt_less_ninety = DateTime->now()->subtract( days => $DEFAULT_INSTRUMENT_UPTIME_INTERVAL );


  foreach my $i (sort {$a <=> $b} keys %{$instrument_run_times}) {
    my $array_of_runs = $instrument_run_times->{$i};

    my $no_changes = scalar@{$instruments} * 2;
    if ($no_changes > $max_number_of_changes) {
      $max_number_of_changes = $no_changes;
    }

    my $change_dates = [];
    foreach my $run (@{$array_of_runs}) {
      my ($y,$m,$d) = $run->{run_end} =~ /(\d+)-(\d+)-(\d+)/xms;
      my $temp_dt = DateTime->new(year => $y, month => $m, day => $d);
      my $day = DateTime->compare( $temp_dt, $dt_less_ninety );
      if ($day >= 0) {
        push @{$change_dates}, $dt_less_ninety->delta_days($temp_dt)->in_units(q{days});
      }
      ($y,$m,$d) = $run->{run_start} =~ /(\d+)-(\d+)-(\d+)/xms;
      $temp_dt = DateTime->new(year => $y, month => $m, day => $d);
      $day = DateTime->compare( $temp_dt, $dt_less_ninety );
      if ($day >= 0) {
        push @{$change_dates}, $dt_less_ninety->delta_days($temp_dt)->in_units(q{days});
      }
    }
    $instrument_run_times->{$i} = $change_dates;
  }

  for my $count (1..$max_number_of_changes) {
    push @{$stripe}, [];
  }

  my $date_ninety_days_ago = $dt_less_ninety->dmy();
  my $date_now = $dt->dmy();
  foreach my $i (sort {$a <=> $b} keys %{$instrument_run_times}) {
    foreach my $array (@{$stripe}) {
      $array->[$stripe_indices->{$i}] = shift@{$instrument_run_times->{$i}};
    }
  }
  foreach my $array (@{$stripe}) {
    foreach my $i (0..$max_number_of_changes) {
      $array->[$i] ||= 0;
    }
  }
  my @graph_columns;
  foreach my $i (@{$instruments}) {
    push @graph_columns, $DEFAULT_INSTRUMENT_UPTIME_INTERVAL;
  }

  unshift @{$stripe}, \@graph_columns;
  unshift @{$stripe}, \@graph_columns;

  my $convert_to_date_code = $self->_convert_to_date_code();
  return {instruments => $instruments, data => $stripe, y_max_value => $DEFAULT_INSTRUMENT_UPTIME_INTERVAL, y_min_value => 0, code => $convert_to_date_code};
}

sub _convert_to_date_code {
  my ($self) = @_;
  my $convert_to_date_code = sub {
    my ($i) = @_;
    return $self->dates_of_last_ninety_days()->[$i];
  };
  return $convert_to_date_code;
}

sub _instrument_run_times {
  my ( $self, $no_of_days, $instrument_model ) = @_;
  $no_of_days ||= $DEFAULT_INSTRUMENT_UPTIME_INTERVAL;
  $no_of_days++;
  $instrument_model = $instrument_model || $self->{inst_format} || q{HK}; # default to GAIIx

  my $q = qq{SELECT i.id_instrument AS id_instrument,
                    i.name AS name,
                    r.id_run AS id_run,
                    rs.date AS run_start,
                    ifnull(run_end.date, DATE(now())) AS run_end
             FROM instrument i,
                  instrument_format i_f,
                  run_status rs,
                  run_status_dict rsd,
                  run r LEFT JOIN
                  (
                   SELECT r.id_run AS id_run, rs.date AS date, rsd.description AS description
                   FROM run r,
                        run_status rs,
                        run_status_dict rsd
                   WHERE rsd.description in ('run complete', 'run cancelled','run stopped early')
                   AND   rsd.id_run_status_dict = rs.id_run_status_dict
                   AND   rs.date > (DATE_SUB(now(), interval $no_of_days day))
                   AND   rs.id_run = r.id_run
                   ORDER BY r.id_run, rs.date
                  ) run_end ON r.id_run = run_end.id_run
             WHERE rsd.description = 'run in progress'
             AND   rsd.id_run_status_dict = rs.id_run_status_dict
             AND   rs.date > (DATE_SUB(now(), interval $no_of_days day))
             AND   rs.id_run = r.id_run
             AND   r.id_instrument = i.id_instrument
             AND   i.id_instrument_format = i_f.id_instrument_format
             AND   i_f.model = ?
             ORDER BY i.id_instrument, rs.date DESC};

  my $dbh = $self->util->dbh();
  my $sth = $dbh->prepare( $q );
  $sth->execute( $instrument_model );

  my $seen = {};
  my $instrument_run_times = {};
  while (my $href = $sth->fetchrow_hashref()) {
    next if ($seen->{$href->{id_run}});
    $seen->{$href->{id_run}}++;
    push @{$instrument_run_times->{$href->{id_instrument}}}, \%{$href};
  }
  return $instrument_run_times;
}

sub instrument_model {
  my ( $self ) = @_;
  if ( ! $self->{instrument_model} ) {
    $self->{instrument_model} = $self->util->cgi->param('inst_format');
  }
  return $self->{instrument_model} || q{};
}

1;
__END__

=head1 NAME

npg::model::instrument_utilisation

=head1 VERSION

$Revision: 15357 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 init - additional handling for creating instrument_utilisation objects by date

  my $oInstrumentUtilisation = npg::model::instrument_utilisation->new({
    'util' => $oUtil,
    'date' => $sDate
  });
  

=head2 default_num_days - returns the default number of days that is used by other methods

=head2 last_x_days - returns utilisation  data for the last number od days (specified by the second argument) in the form of an arrayref of rows, ordered by date, [date, number_of_insts, perc_util, perc_uptime]. If the number of days argument is not supplied, defaults to the number of days returned by $oInstrumentUtilisation->default_num_days method.

  my $aLastXDays = $oInstrumentUtilisation->last_X_days('total_insts|official_insts|prod_insts', $num_days);
  my $aLastXDays = $oInstrumentUtilisation->last_X_days('total_insts|official_insts|prod_insts');

=head2 last_30_days - method for querying the last 30 days worth of data for particular columns, returning an arrayref of rows, ordered by date, [date, number_of_insts, perc_util, perc_uptime]. This method is now deprecated; use last_X_days instead

  my $aLast30Day = $oInstrumentUtilisation->last_30_days('total_insts|official_insts|prod_insts');

=head2 table_data_total_insts - method for calling last X days worth of data for total_insts. If the number of days argument is not supplied, defaults to the number of days returned by $oInstrumentUtilisation->default_num_days method.

  my $aTableDataTotalInsts = $oInstrumentUtilisation->table_data_total_insts($num_days);

=head2 table_data_official_insts - method for calling last X days worth of data for official_insts If the number of days argument is not supplied, defaults to the number of days returned by $oInstrumentUtilisation->default_num_days method.

  my $aTableDataOfficialInsts = $oInstrumentUtilisation->table_data_official_insts($num_days);

=head2 table_data_prod_insts - method for calling last 30 days worth of data for prod_insts. If the number of days argument is not supplied, defaults to the number of days returned by $oInstrumentUtilisation->default_num_days method.

  my $aTableDataProdInsts = $oInstrumentUtilisation->table_data_prod_insts($num_days);

=head2 graph_data - returns the data for a graph of utilization, up-time or utilization as a percentage of up-time for all three instrument categories. If the number of days argument is not supplied, defaults to the number of days returned by $oInstrumentUtilisation->default_num_days method.

  my $aGraphData = $oInstrumentUtilisation->graph_data('utilisation|uptime|utilisation_uptime', $num_days);

=head2 obtain_graph_data - refactored SQL request for graph_data. If the number of days argument is not supplied, defaults to the number of days returned by $oInstrumentUtilisation->default_num_days method.

  my $aObtainGraphData = $oInstrumentUtilisation->obtain_graph_data('utilisation|uptime', $num_days);

=head2 create - wrapper over SUPER::create which enforces a read afterwards to ensure all the fields are filled as the database has them

=head2 instruments - returns an arrayref of instrument objects for all instruments in the database

  my $aInstruments = $oInstrumentUtilisation->instruments();

=head2 gantt_run_timeline_png - returns a png image of the run timelines by instrument gantt style chart

  my $RTpng = $oInstrumentUtilisation->gantt_run_timeline_png();

=head2 gantt_map - returns html which will produce an image_map and the url of the image, which will have running blocks to hover the dates

  my $sGanttMap = $oInstrumentUtilisation->gantt_map($map_id, $url_of_image);

=head2 instrument_model

helper method to retrieve the model/format from the cgi params provided

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

=item npg::model::instrument_status

=item npg::model::instrument_status_dict

=item npg::model::instrument

=item npg::util::image::image_map

=item DateTime

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown, E<lt>ajb@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2009 GRL, by Andy Brown

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
