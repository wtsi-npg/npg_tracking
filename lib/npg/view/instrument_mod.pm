package npg::view::instrument_mod;

use base qw(npg::view);
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars);

use npg::model::instrument_mod;
use npg::model::instrument_mod_dict;

our $VERSION = '0';

sub authorised {
  my $self   = shift;
  my $util   = $self->util();
  my $action = $self->action();
  my $aspect = $self->aspect();

  #########
  # Allow engineers group access to create and update instrument_mod
  #
  if (($action eq 'create' ||
       $action eq 'update' ||
       $aspect eq 'add_ajax') &&
      $util->requestor->is_member_of('engineers')) {
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
  $model->id_user($requestor->id_user());
  $model->date_added($model->dbh_datetime());
  return $self->SUPER::create();
}

sub update {
  my $self = shift;
  my $cgi = $self->util->cgi();
  if (!$cgi->param('remove')) {
    croak 'removal not set';
  }
  my $model = $self->model();
  $model->read();
  $model->date_removed($model->dbh_datetime());
  $model->iscurrent(0);
  return $self->SUPER::update();
}

1;

__END__

=head1 NAME

npg::view::instrument_mod - view handling for instrument_mods

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 authorised - handling for 'pipeline' group access to status creation

=head2 add_ajax - set up id_instrument from CGI block

=head2 create - from CGI inputs, create a mod entry for the instrument

=head2 update - set a mod entry to removed and non-current

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item npg::view

=item strict

=item warnings

=item Carp

=item English

=item npg::model::instrument_mod

=item npg::model::instrument_mod_dict

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 GRL

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
