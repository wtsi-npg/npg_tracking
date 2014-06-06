#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::model::user;
use strict;
use warnings;
use base qw(npg::model);
use npg::model::usergroup;
use npg::model::user2usergroup;
use English qw(-no_match_vars);
use Carp;
use Digest::SHA qw(sha256_hex);;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());

sub fields { return qw(id_user username rfid); }

sub init {
  my $self = shift;

  # rfid's are stored in the database as a sha256 hex string
  if ( $self->{rfid} ) {
    $self->{rfid} = sha256_hex( $self->{rfid} );
  }

  # try to get the id_user from the username (i.e. logged in through sso)
  if ( $self->{'username'} &&
       ! $self->{'id_user'} ) {
    my $query = q(SELECT id_user
                  FROM   user
                  WHERE  username = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref( $query, {}, $self->username() );
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if ( @{$ref} ) {
      $self->{'id_user'} = $ref->[0]->[0];
    }
  }

  my $capture_username = $self->{username};

  # if that failed, see it the user has beeped in their rfid
  if ( $self->{rfid} && ! $self->{id_user} ) {

    $self->{username} = undef;

    my $query = q(SELECT id_user
                  FROM   user
                  WHERE  rfid = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref( $query, {}, $self->rfid() );
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if ( @{$ref} ) {
      $self->{'id_user'} = $ref->[0]->[0];
    }
  }

  if ( ! $self->{id_user} ) {
    $self->{username} = $capture_username || q{public};
  }

  return 1;
}

sub usergroups {
  my $self  = shift;

  if(!$self->{'usergroups'}) {
    my $pkg   = 'npg::model::usergroup';
    my $query = qq(SELECT @{[join q(, ), map { "ug.$_" } $pkg->fields()]}, uug.id_user_usergroup
                   FROM   @{[$pkg->table()]} ug,
                          user2usergroup     uug
                   WHERE  uug.id_user     = ?
                   AND    ug.id_usergroup = uug.id_usergroup);
    $self->{'usergroups'} = $self->gen_getarray( $pkg, $query, $self->id_user());
  }
  return $self->{'usergroups'};
}

sub is_member_of {
  my ($self, $groupname) = @_;
  if(scalar grep { $_->groupname() eq $groupname ||
    (($groupname ne 'analyst') && ($_->groupname() eq 'admin' ))}
     @{$self->usergroups()}) {
    return 1;
  }
  return;
}

sub users {
  my $self = shift;
  return $self->gen_getall();
}

sub runs_loaded {
  my $self = shift;
  if(!$self->{runs_loaded}) {
    my $query = q(SELECT i.name AS instrument, r.id_run AS id_run, DATE(rs.date) AS date
                  FROM   instrument i, run_status rs, run_status_dict rsd, run r
                  WHERE  rs.id_user = ?
                  AND    rs.id_run_status_dict = rsd.id_run_status_dict
                  AND    rsd.description = 'run pending'
                  AND    rs.id_run = r.id_run
                  AND    r.id_instrument = i.id_instrument
                  ORDER BY rs.date DESC);
    my $dbh = $self->util->dbh();
    my $sth = $dbh->prepare($query);
    $sth->execute($self->id_user());
    $self->{runs_loaded} = [];
    while (my $row = $sth->fetchrow_hashref()) {
      push @{$self->{runs_loaded}}, $row;
    }
  }
  return $self->{runs_loaded};
}

1;

__END__

=head1 NAME

npg::model::user - data model for user

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields

array of accessor names

  my @aFields = npg::model::user->fields();
  my @aFields = $oUser->fields();

=head2 init

support loading by user name and rfid as well as id_user

=head2 usergroups

  my $arUsergroups = $oUser->usergroups();

=head2 is_member_of

convenience method for checking group membership of this user

  my $bIsMember = $oUser->is_member_of($sGroupName);

=head2 users

arrayref of all npg::model::users

  my $arAllUsers = $oUser->users();

=head2 runs_loaded

returns an array of all the runs that this user has loaded

  my $aRunsLoaded = $oUser->runs_loaded();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item npg::model

=item npg::model::usergroup

=item npg::model::user2usergroup

=item English

=item Carp

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
