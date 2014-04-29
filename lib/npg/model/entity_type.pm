#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::model::entity_type;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::event_type;
use npg::model::event;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_many('event_type');
__PACKAGE__->has_all();

sub fields {
  return qw(id_entity_type
            description
            iscurrent);
}

sub init {
  my $self = shift;

  if($self->{'description'} &&
     !$self->{'id_entity_type'}) {
    my $query = q(SELECT id_entity_type
                  FROM   entity_type
                  WHERE  description = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->description());

    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{'id_entity_type'} = $ref->[0]->[0];
    }
  }
  return 1;
}

sub events {
  my $self = shift;

  if(!$self->{events}) {
    my $pkg = 'npg::model::event';
    my $query = qq[SELECT @{[join q[, ], map { "e.$_" } $pkg->fields()]}
                   FROM event e,
                        event_type et
                   WHERE e.id_event_type   = et.id_event_type
                   AND   et.id_entity_type = ?];
    $self->{events} = $self->gen_getarray($pkg, $query, $self->id_entity_type());
  }
  return $self->{events};
}

sub current_entity_types {
  my $self = shift;

  if(!$self->{'current_entity_types'}) {
    my $pkg   = ref $self;
    my $query = qq(SELECT @{[join q(, ), $pkg->fields()]}
                   FROM   @{[$pkg->table()]}
                   WHERE  iscurrent = 1);
    $self->{'current_entity_types'} = $self->gen_getarray($pkg, $query);
  }

  return $self->{'current_entity_types'};
}

1;
__END__

=head1 NAME

npg::model::entity_type

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 current_entity_types - arrayref of npg::model::entity_types with iscurrent=1

  my $arCurrentEntityTypes = $oEntityType->current_entity_types();

=head2 entity_types - arrayref of all npg::model::entity_types

  my $arEntityTypes = $oEntityType->entity_types();

=head2 events - arrayref of npg::model::events for this entity_type

  my $arEvents = $oEntityType->events();

=head2 init - additional by-description initialization support

  my $oEntityType = npg::model::entity_type->new({
    'util'        => $oUtil,
    'description' => 'entity_description',
  });

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

=item npg::model::event_type

=item npg::model::event

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 GRL, by Roger Pettett

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
