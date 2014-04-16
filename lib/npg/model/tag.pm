#########
# Author:        ajb
# Created:       2008-03-03
#
package npg::model::tag;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::run;
use npg::model::run_lane;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());

sub fields {
  return qw(
      id_tag
      tag
    );
}

sub init {
  my $self = shift;

  if($self->{'tag'} &&
     !$self->{'id_tag'}) {
    my $query = q(SELECT id_tag
                  FROM   tag
                  WHERE  tag = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->tag());
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{'id_tag'} = $ref->[0]->[0];
    }
  }
  return 1;
}

sub all_tags {
  my $self = shift;
  if (!$self->{all_tags}) {
    my $query = q{SELECT id_tag, tag FROM tag ORDER BY tag};
    $self->{all_tags} = $self->gen_getarray(ref$self, $query);
  }
  return $self->{all_tags};
}

sub runs {
  my ($self) = @_;
  if(!$self->{runs}) {
    my $query = q{SELECT tr.id_run,
                         DATE(tr.date) AS date,
                         tr.id_user,
                         t.tag
                  FROM   tag_run tr, tag t
                  WHERE  t.id_tag = ?
                  AND    t.id_tag = tr.id_tag
                  ORDER BY tr.id_run};
    $self->{runs} = $self->gen_getarray('npg::model::run', $query, $self->id_tag());
  }
  return $self->{runs};
}

sub run_lanes {
  my ($self) = @_;
  if(!$self->{run_lanes}) {
    my $query = q{SELECT trl.id_run_lane AS id_run_lane,
                         DATE(trl.date) AS date,
                         trl.id_user AS id_user,
                         t.tag AS tag
                  FROM   tag_run_lane trl, tag t
                  WHERE  t.id_tag = ?
                  AND    t.id_tag = trl.id_tag
                  ORDER BY trl.id_run_lane};
    $self->{run_lanes} = $self->gen_getarray('npg::model::run_lane', $query, $self->id_tag());
  }
  return $self->{run_lanes};
}

1;
__END__

=head1 NAME

npg::model::tag

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 init - gets info from database to create object via tag

=head2 all_tags - returns arrayref of all tags in table

  my $aAllTags = $oTag->all_tags();

=head2 runs - returns an arrayref containing objects for each of the runs which have been assigned this tag, also including the date and id_user when/who assigned this tag to the run

  my $aRuns = $oTag->runs();

=head2 run_lanes - returns an arrayref containing objects for each of the run lanes which have been assigned this tag, also including the date and id_user when/who assigned this tag to the run lane

  my $aRunLanes = $oTag->run_lanes();

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

=item npg::model::run_lane

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
