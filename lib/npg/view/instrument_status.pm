#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-03-28
# Last Modified: $Date: 2012-02-22 10:12:17 +0000 (Wed, 22 Feb 2012) $
# Id:            $Id: instrument_status.pm 15220 2012-02-22 10:12:17Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg/view/instrument_status.pm $
#
package npg::view::instrument_status;
use base qw(npg::view);
use strict;
use warnings;
use Carp;
use English qw{-no_match_vars};
use npg::model::instrument_status;

our $VERSION = '0';

sub authorised {
  my $self   = shift;

  my $action = $self->action();
  my $aspect = $self->aspect();
  my $requestor = $self->util->requestor();

  #########
  # Allow pipeline group access to the create_xml interface of instrument_status
  #
  if ( $aspect eq 'create_xml' &&
       $requestor->is_member_of( 'pipeline' ) ) {
    return 1;
  }

  if (
      ( $action eq 'create' || $action eq 'read' )
      &&
      ( $requestor->is_member_of( 'engineers' ) ||
        $requestor->is_member_of( 'annotators' ) ||
        $requestor->is_member_of( 'loaders' ) )
     ) {
    return 1;
  }

  return $self->SUPER::authorised();
}

sub add_ajax {
  my $self                  = shift;
  my $cgi                   = $self->util->cgi();
  my $model                 = $self->model();
  my $id_instrument         = $cgi->param('id_instrument');
  $model->{'id_instrument'} = $id_instrument;
  return;
}

sub create {
  my $self            = shift;
  my $model           = $self->model();
  my $requestor       = $self->util->requestor();
  $model->{'id_user'} = $requestor->id_user();
  return $self->SUPER::create();
}

sub list_up_down_xml {
  my ($self) = @_;
  return 1;
}

sub list_graphical {
  my ($self, @args) = @_;
  $self->get_inst_format();
  return 1;
}
sub list_gantt_chart_legend_png {
  my ($self) = @_;
  my $png;
  return $png;
}
sub list_gantt_chart_png {
  my ($self) = @_;
  my $model = $self->model();
  my $inst_format = $self->get_inst_format();
  return $model->gantt_chart_png( q{}, $inst_format );
}

sub list_combined_utilisation_and_uptime_gantt_png {
  my ($self) = @_;
  my $model = $self->model();
  my $inst_format = $self->get_inst_format();
  return $model->combined_utilisation_and_uptime_gantt_png( $inst_format );
}

1;

__END__

=head1 NAME

npg::view::instrument_status - view handling for instrument_statuses

=head1 VERSION



=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 authorised - handling for 'pipeline' group access to status creation

=head2 add_ajax - set up id_instrument from CGI block

=head2 create - set up requestor's id_user

=head2 list_up_down_xml - handling to return an XML of all the up and down statuses for an instrument

=head2 list_graphical - handler for returning the list_graphical view

=head2 list_gantt_chart_png - returns png image chart of all instruments up/down as gantt chart, with instrument annotations added as points

=head2 list_gantt_chart_legend_png - handler to return a png legend for gantt chart

=head2 combined_utilisation_and_uptime_gantt_png
=head2 list_combined_utilisation_and_uptime_gantt_png - handler to return the combined utilisation and up/down gantt chart

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

npg::view

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 GRL, by Roger Pettett

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
