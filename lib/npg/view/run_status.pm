#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::view::run_status;
use base qw(npg::view);
use strict;
use warnings;
use English qw(-no_match_vars);
use Carp;

our $VERSION = '0';

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  my $id   = $self->model->id_run_status() || q();
  return $self;
}

sub authorised {
  my $self      = shift;
  my $util      = $self->util();
  my $action    = $self->action();
  my $aspect    = $self->aspect();
  my $requestor = $util->requestor();

  #########
  # Allow pipeline group access to the create_xml interface of run_status
  #
  if($aspect eq 'create_xml' &&
     $requestor->is_member_of('pipeline')) {
    return 1;
  }

  if(($action eq 'create' ||
      $action eq 'read'   ||
      $action eq 'list') &&
     ($requestor->is_member_of('loaders')    ||
      $requestor->is_member_of('engineers')  ||
      $requestor->is_member_of('annotators') ||
      $requestor->is_member_of('manual_qc')
  )) {
    return 1;
  }

  return $self->SUPER::authorised();
}

sub add_ajax {
  my $self           = shift;
  my $cgi            = $self->util->cgi();
  my $model          = $self->model();
  my $id_run         = $cgi->param('id_run');
  $model->{'id_run'} = $id_run;
  return;
}

sub create {
  my $self              = shift;
  my $cgi               = $self->util->cgi();
  my $model             = $self->model();
  my $requestor         = $self->util->requestor();
  $cgi->param('id_user', $requestor->id_user());
  $model->{update_pair} = $cgi->param('update_pair');

  return $self->SUPER::create();
}

sub list_xml {
  my $self = shift;
  my $template = q[run_status_list_xml.tt2];
  print "Content-type: text/xml\n\n" or croak $OS_ERROR;
  $self->process_template('run_status_list_xml.tt2');
  # flush and close
  $self->output_finished(1);
  return 1;
}

1;

__END__

=head1 NAME

npg::view::run_status - view handling for run_statuses

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 authorised - handling for 'pipeline' group access to status creation

=head2 add_ajax - set up id_run from CGI block

=head2 create - set up requestor's id_user

=head2 new

=head2 list_xml - handling for streamed XML list response

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
