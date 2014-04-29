#########
# Author:        ajb
# Created:       2009-02-05
#
package npg::view::instrument_utilisation;
use base qw(npg::view);
use strict;
use warnings;
use English qw(-no_match_vars);
use Carp;
use npg::util::image::graph;
use Readonly;
use Math::Round qw(round);

our $VERSION = '0';

Readonly::Scalar our $PLOTTER_WIDTH  => 1000;
Readonly::Scalar our $PLOTTER_HEIGHT => 400;
Readonly::Scalar our $PERCENTAGE     => 100;

sub authorised {
  my ($self, @args) = @_;
  my $requestor = $self->util->requestor();

  if ($requestor->username() eq 'pipeline') {
    return 1;
  }
  return $self->SUPER::authorised(@args);
}

sub read {    ## no critic (ProhibitBuiltinHomonyms)
  my ($self, @args) = @_;
  if ($self->model->id_instrument_utilisation() eq 'graphical') {
    return $self->list_graphical();
  } elsif ($self->model->id_instrument_utilisation() eq 'text90') {
    return $self->list_text90();
  }  elsif ($self->model->id_instrument_utilisation() eq 'line90') {
    return $self->list_line90();
  }
  return $self->SUPER::read();
}

sub list_graphical {
  my ($self) = @_;
  return 1;
}

sub list_graphical_line {
  my ($self) = @_;
  return 1;
}

sub list_text90 {
  my ($self) = @_;
  return 1;
}


sub list_graphical_line90 {
  my ($self) = @_;
  return 1;
}


sub list_graph_png {

  my ($self) = @_;
  my $model = $self->model();

  my $cgi = $self->util->cgi();
  my $type = $cgi->param( q{type} );
  $type = $model->sanitise_input( $type );
  my $graph_type = $cgi->param( q{graph_type} ) || 'bars';
  $graph_type = $model->sanitise_input( $graph_type );
  my $instrument_format = $cgi->param( q{inst_format} ) || q{HK};
  $instrument_format = $model->sanitise_input( $instrument_format );
  my $default_num_days = $model->default_num_days();
  my $num_days = $cgi->param('num_days') || $default_num_days;
  $num_days = $model->sanitise_input( $num_days );

  my $data = $model->graph_data($type, $num_days, $instrument_format);

  my $graph = npg::util::image::graph->new();

  $instrument_format = $instrument_format eq 'HK' ? q{GAIIx}
                     :                              $instrument_format
                     ;

  my $title = $type eq 'utilisation' ? 'Daily Percentage Utilisation (Seconds of the Day) - ' . $instrument_format
            : $type eq 'uptime'      ? 'Daily Percentage Uptime (Seconds of the Day) - ' . $instrument_format
            :                          'Utilisation as a Percentage of Uptime - ' . $instrument_format
            ;

  my $x_label_skip = round($num_days/$default_num_days);


  return $graph->plotter($data, {
         width             => $PLOTTER_WIDTH,
         height            => $PLOTTER_HEIGHT,
         x_label           => 'date',
         y_label           => 'percentage',
         y_min_value       => 0,
         y_max_value       => $PERCENTAGE,
         title             => $title,
         legend            => ['Total', 'Less Hot Spare', 'Production'],
         x_labels_vertical => 1,
         x_label_skip      => $x_label_skip,
      }, $graph_type);
}

sub list_gantt_run_timeline_png {
  my ($self) = @_;
  my $model = $self->model();
  my $inst_format = $self->get_inst_format();
  return $model->gantt_run_timeline_png( 0, $inst_format );
}

sub list_gantt_run_timeline_chart_legend_png {
  my ($self) = @_;
  return 1;
}

1;

__END__

=head1 NAME

npg::view::instrument_utilisation - view handling for instrument_utilisation

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 authorised - added authorization to allow pipeline to CRUD

=head2 read - wrapper to catch graphical and actually render list_graphical (RESTful style URL)

=head2 list_graphical - handler to render the display which will show the graphs, in bar chart format (last 30 days)

=head2 list_graphical_line - handler to render the display which will show the graphs, in line chart format (last 30 days)

=head2 list_text90 - handler to return the utilisation data in text format for the last 90 days

=head2 list_graphical_line90 - handler to return the utilisation data in as a line chart for the last 90 days

=head2 list_graph_png - handler to render a PNG image of the instrument_utilisation data for the last X days.  If the number of days argument is not supplied, defaults to the number of days returned by npg::model::instrument_utilisation->default_num_days method.
  
  my $num_days = 90;
  my $png = $oInstrumentUtilisationView->list_graph_png($num_days);
  $png    = $oInstrumentUtilisationView->list_graph_png();

=head2 list_gantt_run_timeline_png - handler to render a timeline image of running runs on instruments

=head2 list_gantt_run_timeline_chart_legend_png - handler to render a legend for the gantt_run_timeline

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item npg::view

=item strict

=item warnings

=item English

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown, E<lt>ajb@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 GRL, by Andy Brown

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
