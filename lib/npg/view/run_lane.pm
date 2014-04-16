#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::view::run_lane;
use base qw(npg::view);
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars);
use npg::model::run_lane;
use npg::model::run_status;
use npg::model::run_status_dict;
use Readonly;

our $VERSION = '0';

Readonly::Scalar our $GRAPH_HEIGHT => 200;
Readonly::Scalar our $GRAPH_WIDTH  => 400;

sub authorised {
  my $self      = shift;
  my $util      = $self->util();
  my $aspect    = $self->aspect();
  my $action    = $self->action();
  my $requestor = $util->requestor();

  if($aspect eq 'update_xml' &&
     $requestor->is_member_of('pipeline')) {
    return 1;
  }

  if( $aspect eq 'update_tags' && ($requestor->is_member_of('annotators') || $requestor->is_member_of('manual_qc')) ) {
    return 1;
  }

  return $self->SUPER::authorised();
}

sub update {
  my ($self, @args) = @_;
  my $util     = $self->util();
  my $cgi      = $util->cgi();
#  my $good_bad = $cgi->param('good_bad');

#  if(defined $good_bad && $good_bad eq q[]) {
#    $cgi->delete('good_bad');
#  }

  return $self->SUPER::update(@args);
}

#sub update_good_bad {
#  my ($self, @args) = @_;
#  $self->SUPER::update(@args);
#  my $run_model = $self->model->run();
#
#  for my $run_lane (@{$run_model->run_lanes()}) {
#    if(! defined $run_lane->good_bad()) {
#      return 1;
#    }
#  }
#
#  $self->model->{last_lane}++;
#  return $self->update_status_to_qc_complete();
#}

# TODO: move this into model::run.pm where it belongs - this isn't an operation on one run_lane.
#sub update_all_good_bad {
#  my $self      = shift;
#  my $util      = $self->util;
#  my $cgi       = $util->cgi;
#  my $good_bad  = $cgi->param('good_bad');
#  my $model     = $self->model;
#  my $run_model = $model->run;
#  my $tr_state  = $util->transactions;
#
#  $util->transactions(0);
#
#  if(defined $good_bad && $good_bad eq q[]) {
#    $good_bad = undef;
#  }
#
#  for my $run_lane (@{$run_model->run_lanes}) {
#    if(!defined $good_bad ||             # resetting lanes
#       !defined $run_lane->good_bad()) { # set remaining lanes
#      $run_lane->good_bad($good_bad);
#      $run_lane->update();
#    }
#  }
#
#  $util->transactions($tr_state);
#
#  if(!defined $good_bad) {
#    #########
#    # if all lanes have been UNset, revert run status back to qc review pending
#    #
#    my $rsd = npg::model::run_status_dict->new({
#                 description => 'qc review pending',
#                 util        => $util,
#                 });
#    my $run_status = npg::model::run_status->new({
#              id_run             => $model->id_run,
#              id_run_status_dict => $rsd->id_run_status_dict,
#              id_user            => $util->requestor->id_user,
#              util               => $util,
#             });
#    $model->{qc_reverted} = 1;
#    return $run_status->create;
#  }
#
#  return $self->update_status_to_qc_complete;
#}

sub update_status_to_qc_complete {
  my $self  = shift;
  my $model = $self->model;
  my $util  = $self->util;
  my $rsd   = npg::model::run_status_dict->new({
                  description => 'qc complete',
                  util        => $util,
                 });
  my $run_status = npg::model::run_status->new({
                  id_run             => $model->id_run,
                  id_run_status_dict => $rsd->id_run_status_dict,
                  id_user            => $util->requestor->id_user,
                  util               => $util,
                 });
  return $run_status->create;
}

sub list_tag {
  my ($self) = @_;
  return;
}

sub update_tags {
  my $self = shift;
  my $util = $self->util();
  my $cgi  = $util->cgi();
  my $dbh  = $util->dbh();

  my (@tags, @specified_tags);
  if ($cgi->param('tags')) { @tags = split q{ }, $cgi->param('tags'); };
  if ($cgi->param('tagged_already')) { @specified_tags = split q{ }, $cgi->param('tagged_already'); };
  my (%tagged_already, %saving_tags, %in_save_box, %removing_tags);

  for my $tag (@specified_tags) {
    $tagged_already{$tag}++;
  }

  for my $tag (@tags) {
    $in_save_box{lc$tag}++;
    if ($tagged_already{$tag}) {
      next;
    }
    $saving_tags{lc$tag}++;
  }

  for my $tag (@specified_tags) {
    if ($in_save_box{$tag}) {
      next;
    }
    $removing_tags{$tag}++;
  }

  my @tags_to_save   = sort keys %saving_tags;
  my @tags_to_remove = sort keys %removing_tags;
  my $tr_state = $self->util->transactions();

  $self->util->transactions(0);
  eval {
    if (scalar @tags_to_save) {
      $self->model->save_tags(\@tags_to_save, $self->util->requestor());
    }
    if (scalar @tags_to_remove) {
      $self->model->remove_tags(\@tags_to_remove, $self->util->requestor());
    }
    1;

  } or do {
    $self->util->transactions($tr_state);

    $tr_state and $dbh->rollback();
    croak $EVAL_ERROR . q[Rolled back attempt to save info for the tags for run lane ] . $self->model->id_run_lane();
  };

  $self->util->transactions($tr_state);

  $tr_state and $dbh->commit();
  return;
}

sub render {
  my ($self, @args) = @_;

  my $aspect = $self->aspect();
  if($aspect eq 'read_png') {
    return $self->read_png();
  }

  return $self->SUPER::render(@args);
}

1;

__END__

=head1 NAME

npg::view::run_lane - view handling for run_lanes

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 authorised - adds in additional authorization for certain aspects/usergroup members

=head2 update - handling NULL good_bad parameter

=head2 update_good_bad - handles incoming setting of good/bad run lane to database

=head2 update_all_good_bad - handles setting of all run_lanes to good or bad if not already assigned good/bad

=head2 list_tag

=head2 update_tags - handles incoming form of tags to be saved for this run_lane

=head2 render - handles rendering correct view type

=head2 update_status_to_qc_complete - handles setting the run status to 'qc complete' when the last run lane has been QC reviewed

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

=item npg::model::run_lane

=item npg::model::run_status

=item npg::model::run_status_dict

=item Readonly

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
