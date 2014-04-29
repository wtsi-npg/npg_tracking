#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::model::user2usergroup;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::user;
use npg::model::usergroup;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_a([qw(user usergroup)]);

sub fields {
  return qw(id_user_usergroup id_user id_usergroup);
}

sub init {
  my ( $self ) = @_;

  if ( ! $self->{id_user_usergroup} &&
       $self->{id_user} &&
       $self->{id_usergroup} ) {

    my $query = q{SELECT id_user_usergroup FROM user2usergroup WHERE id_user = ? AND id_usergroup = ?};
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_user(), $self->id_usergroup());
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if( @{ $ref } ) {
      $self->{id_user_usergroup} = $ref->[0]->[0];
    }
  }
  return 1;
}

1;
__END__

=head1 NAME

npg::model::user2usergroup

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

npg::model::user2usergroup models abstract relationships between users and user groups (membership)

=head1 SUBROUTINES/METHODS

=head2 fields - the fields for this model

 my @aFields = $oUser2Usergroup->fields();
 my @aFields = npg::model::user2usergroup->fields();

=head2 user - the npg::model::user in this relationship

 my $oUser = $oUser2Usergroup->user();

=head2 usergroup - the npg::model::usergroup in this relationship

 my $oUserGroup = $oUser2Usergroup->usergroup();

=head2 init

On construction, can retrieve the object id, if already stored
in the database, based on the id of the user and the usergroup.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item npg::model

=item English

=item Carp

=item npg::model::user

=item npg::model::usergroup

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
