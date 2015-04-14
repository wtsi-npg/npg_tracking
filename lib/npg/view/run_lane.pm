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

our $VERSION = '0';

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
    croak $EVAL_ERROR .
      q[Rolled back attempt to save info for the tags for run lane ] .
      $self->model->id_run_lane();
  };

  $self->util->transactions($tr_state);

  $tr_state and $dbh->commit();
  return;
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

=head2 list_tag

=head2 update_tags - handles incoming form of tags to be saved for this run_lane

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
