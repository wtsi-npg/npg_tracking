#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::model::run_lane;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::run;
use npg::model::tag;
use npg::model::tag_run_lane;
use npg::model::run_lane_annotation;
use npg::model::annotation;
use Readonly;

our $VERSION = '0';
Readonly::Scalar our $GOOD_CLUSTERS_PF        => 10_000;
Readonly::Scalar our $GOOD_PERC_ERROR_RATE_PF => 1;
Readonly::Scalar our $GOOD_PERC_CLUSTERS_PF   => 45;
Readonly::Scalar our $LOWEST_PERC_DIFFERENCE  => 0.925;
Readonly::Scalar our $HIGHEST_PERC_DIFFERENCE => 1.075;

Readonly::Scalar our $IS_GOOD_PASS   => 1;
Readonly::Scalar our $IS_GOOD_FAIL   => 0;
Readonly::Scalar our $IS_GOOD_UNSURE => 2;

Readonly::Scalar our $MEGABASES      => 1_000_000;

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_a([qw(run)]);
__PACKAGE__->has_many('run_lane_annotation');
__PACKAGE__->has_many_through('annotation|run_lane_annotation');

sub fields {
  return qw(id_run_lane
            id_run
            tile_count
            tracks
            position);
}

sub init {
  my ( $self ) = @_;

  if ( ! $self->{id_run_lane}
       && $self->{id_run}
       && $self->{position} ) {

    my $query = q(SELECT id_run_lane
                  FROM   run_lane
                  WHERE  id_run = ?
                  AND    position = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->{id_run}, $self->{position});

    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{'id_run_lane'} = $ref->[0]->[0];
    }
  }
  return 1;
}

sub recent_run_lanes {
  my $self  = shift;
  my $pkg   = ref $self;
  my $query = qq(SELECT @{[join q(, ), map { "rl.$_ AS $_" } $pkg->fields()]}
                 FROM   run_lane   rl,
                        run_status rs
                 WHERE  rl.id_run    = rs.id_run
                 AND    rs.iscurrent = 1
                 AND    rs.date      > DATE_SUB(NOW(), INTERVAL 14 DAY));
  return $self->gen_getarray($pkg, $query);
}

sub tags {
  my $self = shift;
  if(!$self->{tags}) {
    my $query = q{SELECT tf.frequency, t.tag, t.id_tag, trl.id_user, DATE(trl.date) AS date
                  FROM   tag_frequency tf, tag t, tag_run_lane trl, entity_type e
                  WHERE  trl.id_run_lane = ?
                  AND    t.id_tag  = trl.id_tag
                  AND    tf.id_tag = t.id_tag
                  AND    tf.id_entity_type = e.id_entity_type
                  AND    e.description = ?
                  ORDER BY t.tag};
    $self->{tags} = $self->gen_getarray('npg::model::tag', $query, $self->id_run_lane(), $self->model_type());
  }
  return $self->{tags};
}

sub save_tags {
  my ($self, $tags_to_save, $requestor) = @_;
  my $util        = $self->util();
  my $dbh         = $util->dbh();
  my $date        = $dbh->selectall_arrayref(q{SELECT DATE(NOW())}, {})->[0]->[0];
  my $entity_type = npg::model::entity_type->new({description => $self->model_type(), util => $util});
  my $tr_state    = $util->transactions();
  $util->transactions(0);
  eval {
    for my $tag (@{$tags_to_save}) {
      $tag = npg::model::tag->new({
                                  tag  => $tag,
                                  util => $util,
                                  });

      if (!$tag->id_tag()) {
        $tag->create();
      }

      my $tag_run_lane = npg::model::tag_run_lane->new({
                                                      util         => $util,
                                                      id_tag       => $tag->id_tag(),
                                                      id_run_lane  => $self->id_run_lane(),
                                                      });
      $tag_run_lane->date($date);
      $tag_run_lane->id_user($requestor->id_user());
      $tag_run_lane->create();

      my $tag_freq = 'npg::model::tag_frequency'->new({
                                                      id_tag => $tag->id_tag(),
                                                      id_entity_type => $entity_type->id_entity_type,
                                                      util => $util,
                                                      });

      my $freq = $dbh->selectall_arrayref(q{SELECT COUNT(id_tag) FROM tag_run_lane WHERE id_tag = ?}, {}, $tag->id_tag())->[0]->[0];
      $tag_freq->frequency($freq);
      $tag_freq->save();
    }
    1;

  } or do {
    $util->transactions($tr_state);
    $tr_state and $dbh->rollback();
    croak $EVAL_ERROR . q{<br />rolled back attempt to save info for the tags for run_lane } . $self->id_run_lane();
  };

  $util->transactions($tr_state);
  $tr_state and $dbh->commit();
  return;
}


sub remove_tags {
  my ($self, $tags_to_remove, $requestor) = @_;
  my $util        = $self->util();
  my $dbh         = $util->dbh();
  my $entity_type = npg::model::entity_type->new({description => $self->model_type(), util => $util});
  my $tr_state    = $util->transactions();
  $util->transactions(0);

  eval {
    for my $tag (@{$tags_to_remove}) {
      $tag = npg::model::tag->new({
                                  tag  => $tag,
                                  util => $util,
                                  });
      my $tag_run_lane = npg::model::tag_run_lane->new({
                                                       id_tag      => $tag->id_tag(),
                                                       id_run_lane => $self->id_run_lane(),
                                                       util        => $util,
                                                       });
      $tag_run_lane->delete();
      my $tag_freq = 'npg::model::tag_frequency'->new({
                                                      id_tag         => $tag->id_tag(),
                                                      id_entity_type => $entity_type->id_entity_type,
                                                      util           => $util,
                                                      });
      my $freq = $dbh->selectall_arrayref(q{SELECT COUNT(id_tag) FROM tag_run_lane WHERE id_tag = ?}, {}, $tag->id_tag())->[0]->[0];
      $tag_freq->frequency($freq);
      $tag_freq->save();
    }
    1;

  } or do {
    $util->transactions($tr_state);
    $tr_state and $dbh->rollback();
    croak $EVAL_ERROR . q{<br />rolled back attempt to delete info for the tags for run lane } . $self->id_run_lane();
  };

  $util->transactions($tr_state);
  $tr_state and $dbh->commit();
  return;
}

1;
__END__

=head1 NAME

npg::model::run_lane

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 init

enable object to be obtained from database if id_run and position supplied

=head2 run - npg::model::run containing this run_lane

  my $oRun = $oRunLane->run();

=head2 recent_run_lanes - Arrayref of npg::model::run_lanes (by default within the last 14 days)

  my $arRunlanes = $oRunLane->recent_run_lanes();

=head2 tags - returns arrayref containing tag objects, that have been linked to this run lane, that also have 'date' the tag was saved for this run lane, 'id_user' of the person who gave this run lane this tag, and frequency this tag has been used on run lanes 

  my $aTags = $oRun->tags();

=head2 save_tags - saves tags for run lane. expects arrayref of tags and then goes out to save the tag if not already in database, updates the frequency seen for run lane entity type, and saves in join table with id_user and date when saved

  eval { $oRunLane->save_tags(['tag1','tag2'], $oRequestor); };

=head2 remove_tags - removes tags for a run lane. expects arrayref of tags and then removes the tag_run_lane entry and updates the frequency

  eval { $oRunLane->remove_tags(['tag1','tag2'], $oRequestor); };

=head2 annotations - arrayref of npg::model::annotations for this run

  my $arAnnotations = $oRunLane->annotations();

=head2 run_lane_annotations - arrayref of npg::model::run_lane_annotation objects for this run

  my $arRunLaneAnnotations = $oRunLane->run_lane_annotations();
  my $arAnnotations    = [map { $_->annotation() } @{$oRunLaneAnnotations}];

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

=item npg::model::run

=item npg::model::tag

=item npg::model::tag_run_lane

=item npg::model::run_lane_annotation

=item npg::model::annotation

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
