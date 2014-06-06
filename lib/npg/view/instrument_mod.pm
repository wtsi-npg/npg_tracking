#########
# Author:        ajb
# Created:       2007-03-27
#
package npg::view::instrument_mod;
use base qw(npg::view);
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars);
use npg::model::instrument_mod;
use npg::model::instrument_mod_dict;
use Readonly;

our $VERSION = '0';

Readonly::Scalar our $LIMIT_ATOM_ENTRIES => 40;

sub authorised {
  my $self   = shift;
  my $util   = $self->util();
  my $action = $self->action();
  my $aspect = $self->aspect();

  #########
  # Allow pipeline group access to the create_xml interface of instrument_mod
  #
  if ($aspect eq 'create_xml' &&
      $util->requestor->is_member_of('pipeline')) {
    return 1;
  }

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

sub update_mods {
  my $self = shift;
  my $util = $self->util();
  my $cgi = $util->cgi();
  $cgi->param('remove',1);
  my $model = $self->model();
  my @id_instruments = $cgi->param('id_instrument');
  my $iscurrent = $cgi->param('iscurrent');
  my $id_instrument_mod_dict = $cgi->param('id_instrument_mod_dict');
  my $id_user = $util->requestor->id_user();
  my $tr_state = $util->transactions();
  $util->transactions(0);
  my $date = $model->dbh_datetime();

  eval {
    my $imd = npg::model::instrument_mod_dict->new({util => $util, id_instrument_mod_dict => $id_instrument_mod_dict});
    my $im_description = $imd->description();
    foreach my $id_instrument (@id_instruments) {
      my $ins = npg::model::instrument->new({util => $util, id_instrument => $id_instrument});
      my $mods = $ins->instrument_mods();
      foreach my $mod (@{$mods}) {
        if ($mod->instrument_mod_dict->description() eq $im_description && $mod->iscurrent()) {
          $mod->iscurrent(0);
          $mod->date_removed($date);
          $mod->update();
          last;
        }
      }
      my $new_mod = npg::model::instrument_mod->new({
                 util => $util,
                 id_instrument => $id_instrument,
                 id_instrument_mod_dict => $id_instrument_mod_dict,
                 id_user    => $id_user,
                 date_added => $date,
                 iscurrent  => $iscurrent,
                });
      $new_mod->create();
    }
    1;

  } or do {
    $util->transactions($tr_state);
    $util->dbh->rollback();
    croak $EVAL_ERROR;
  };

  $util->transactions($tr_state);

  eval {
    $tr_state and $util->dbh->commit();
    1;

  } or do {
    $util->dbh->rollback();
    croak $EVAL_ERROR;
  };

  return 1;
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

=head2 update_mods - batch update instrument mods. Handles making the existing mod of that type which is current non-current, and then creates new mod

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

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

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
