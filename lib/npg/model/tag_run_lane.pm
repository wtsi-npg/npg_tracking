#########
# Author:        ajb
# Created:       2008-03-03
#
package npg::model::tag_run_lane;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());

sub fields {
  return qw(
      id_tag_run_lane
      id_tag
      id_run_lane
      id_user
      date
    );
}

sub init {
  my $self = shift;

  if($self->{'id_tag'} &&
     $self->{'id_run_lane'} &&
     !$self->{'id_tag_run_lane'}) {
    my $query = q(SELECT id_tag_run_lane, id_user, date
                  FROM   tag_run_lane
                  WHERE  id_tag = ?
                  AND    id_run_lane = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_tag(), $self->id_run_lane());

    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{id_tag_run_lane} = $ref->[0]->[0];
      $self->{id_user}         = $ref->[0]->[1];
      $self->{date}            = $ref->[0]->[2];
    }
  }
  return 1;
}

1;
__END__

=head1 NAME

npg::model::tag_run_lane

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 init - gets info from database to create object via id_tag and id_run_lane

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
