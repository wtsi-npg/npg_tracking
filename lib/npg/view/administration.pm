#########
# Author:        ajb
# Created:       2008-04-24
#
package npg::view::administration;
use strict;
use warnings;
use English qw(-no_match_vars);
use Carp;
use base qw(npg::view);
use npg::model::administration;
use npg::model::instrument_mod_dict;
use npg::model::instrument_status_dict;
use npg::model::user;
use npg::model::usergroup;
use npg::model::entity_type;
use npg::model::run_status_dict;
use npg::model::user2usergroup;

our $VERSION = '0';

sub authorised {
  my $self = shift;
  my $util   = $self->util();
  my $action = $self->action();
  my $aspect = $self->aspect();
  my $requestor = $util->requestor();

  if(($aspect eq 'create_instrument_mod' || $aspect eq 'create_instrument_status')
      && $requestor->is_member_of('engineers')) {
    return 1;
  }

  return $self->SUPER::authorised();
}

sub create_instrument_mod {
  my $self = shift;
  my $util = $self->util();
  my $cgi = $util->cgi();
  my $description = $cgi->param('description');
  my $new_description = $cgi->param('new_description');
  my $revision = $cgi->param('revision');
  $description ||= $new_description;
  if (!$description || !$revision) {
    croak "description ($description) and/or revision ($revision) is missing";
  }
  my $imd = npg::model::instrument_mod_dict->new({util => $util, description => $description, revision => $revision});
  $imd->create();
  return;
}

sub create_instrument_status {
  my $self = shift;
  my $util = $self->util();
  my $cgi = $util->cgi();
  my $description = $cgi->param('description');
  if (!$description) {
    croak 'No status given';
  }
  my $isd = npg::model::instrument_status_dict->new(
    {util => $util, description => $description, iscurrent => 1,});
  $isd->create();
  return;
}

sub create_user {
  my $self = shift;
  my $util = $self->util();
  my $cgi = $util->cgi();
  my $username = $cgi->param('username');
  if (!$username) {
    croak 'No username given';
  }
  my $user = npg::model::user->new({
    util       => $util,
    username  => $username,
    iscurrent => 1});
  $user->create();
  return;
}

sub create_usergroup {
  my $self = shift;
  my $util = $self->util();
  my $cgi = $util->cgi();
  my $groupname = $cgi->param('groupname');
  my $description = $cgi->param('description');
  my $is_public = $cgi->param('is_public');
  if (!$groupname || !$description) {
    croak 'No groupname and/or group description given';
  }
  my $usergroup = npg::model::usergroup->new({
    util        => $util,
    groupname   => $groupname,
    description => $description,
    is_public   => $is_public,
    iscurrent   => 1
  });
  $usergroup->create();
  return;
}

sub create_entity_type {
  my $self = shift;
  my $util = $self->util();
  my $cgi = $util->cgi();
  my $description = $cgi->param('description');
  my $iscurrent = $cgi->param('iscurrent');
  if (!$description) {
    croak 'No entity type given';
  }
  my $et = npg::model::entity_type->new({util => $util, description => $description, iscurrent => $iscurrent});
  $et->create();
  return;
}

sub create_run_status {
  my $self = shift;
  my $util = $self->util();
  my $cgi = $util->cgi();
  my $description = $cgi->param('description');
  if (!$description) {
    croak 'No status given';
  }
  my $rsd = npg::model::run_status_dict->new({util => $util, description => $description});
  $rsd->create();
  return;
}

sub create_user_to_usergroup {
  my $self = shift;
  my $util = $self->util();
  my $cgi = $util->cgi();
  my $id_user = $cgi->param('id_user');
  my $id_usergroup = $cgi->param('id_usergroup');
  if (!$id_user || !$id_usergroup) {
    croak 'No user and/or usergroup given';
  }
  my $uug = npg::model::user2usergroup->new({util => $util, id_user => $id_user, id_usergroup => $id_usergroup});
  $uug->create();
  return;
}

1;
__END__

=head1 NAME

npg::view::administration

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 authorised - handles authorization

=head2 create_instrument_mod - handles creation of an instrument modification dictionary reference

=head2 create_instrument_status - handles creation of an instrument status dictionary reference

=head2 create_user - handles creating a user for the system

=head2 create_usergroup - handles creation of a new user group

=head2 create_entity_type - handles creation of an entity type

=head2 create_run_status - handles creation of a new run status

=head2 create_user_to_usergroup - handles adding a user to a user group for permissions

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item English

=item Carp

=item base

=item npg::view

=item npg::model::administration

=item npg::model::instrument_mod_dict

=item npg::model::instrument_status_dict

=item npg::model::user

=item npg::model::usergroup

=item npg::model::entity_type

=item npg::model::run_status_dict

=item npg::model::user2usergroup

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger M Pettett

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 GRL, by Roger Pettett

This program is free software: you can redistribute it and/or modify
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
