package npg::authentication::sanger_oidc;

use strict;
use warnings;

our $VERSION = '0';

sub new {
  my ($class) = @_;
  my $self = {};

  $self->{claims} = {
    name     => $ENV{'OIDC_CLAIM_name'},
    username => $ENV{'OIDC_CLAIM_preferred_username'},
    };

  bless $self, $class;
  return $self;
}

sub name {
  my $self = shift;
  return $self->{claims}->{name};
}

sub username {
  my $self = shift;
  my $preferred_username = $self->{claims}->{username} || q{};

  if ($preferred_username) {
    return (split /@/smx, $preferred_username)[0];
  }
  return;
}
1;
=pod

=head1 NAME

npg::authentication::sanger_oidc - Simple OIDC claim wrapper

=head1 VERSION

=head1 SYNOPSIS

  use npg::authentication::sanger_oidc;

  my $auth = npg::authentication::sanger_oidc->new();

  print $auth->name;
  print $auth->username;

=head1 DESCRIPTION

This module provides a lightweight interface for accessing
OpenID Connect (OIDC) claims and tokens exposed via environment
variables by Apache authentication modules.

It is intended for use in CGI-based Perl applications where OIDC
authentication is handled upstream (e.g., by mod_auth_openidc).

The module reads standard C<OIDC_CLAIM_*> environment variables and
provides convenient accessor methods.

=head1 SUBROUTINES/METHODS

=head1 CONSTRUCTOR

=head2 new

  my $auth = npg::authentication::sanger_oidc->new();

Creates a new instance and loads OIDC claims and tokens from the
environment.

Currently only few user attributes are fetched from OIDC. Additional,
attributes can be fetched as below:

sub new {
  my ($class) = @_;
  my $self = {};

  $self->{claims} = {
    sub      => $ENV{'OIDC_CLAIM_sub'},
    email    => $ENV{'OIDC_CLAIM_email'},
    name     => $ENV{'OIDC_CLAIM_name'},
    username => $ENV{'OIDC_CLAIM_preferred_username'},
    groups   => $ENV{'OIDC_CLAIM_groups'},
    };

  $self->{tokens} = {
    access_token => $ENV{'OIDC_access_token'},
    id_token     => $ENV{'OIDC_id_token'},
  };

  bless $self, $class;
  return $self;
}

=head1 METHODS

=head2 name

Returns the user's display name.

=head2 username

Returns the preferred username.

=head2 Additional methods

Subject: Returns the subject (unique user identifier).

sub subject {
  my $self = shift;
  return $self->{claims}->{sub};
}

Email: Returns the user's email address.

sub email {
  my $self = shift;
  return $self->{claims}->{email};
}

Groups: Returns the raw groups string as provided by the OIDC provider.

sub groups {
  my $self = shift;
  return $self->{claims}->{groups};
}

Access Token: Returns the OIDC access token.

sub access_token {
  my $self = shift;
  return $self->{tokens}->{access_token};
}

ID Token: Returns the OIDC ID token.

sub id_token {
  my $self = shift;
  return $self->{tokens}->{id_token};
}

has_group:

Returns true if the user is a member of the specified group.
Group membership is determined by splitting the C<groups> string
on commas.

sub has_group {
  my ($self, $group) = @_;
  return 0 if !$self->groups;

  return grep { $_ eq $group }
    map  { s/^\s+|\s+$//grxms }
    split /\s*,\s*/xsm, $self->groups;
}

=head1 ENVIRONMENT

This module relies on the following environment variables being set:

=over 4

=item * OIDC_CLAIM_name

=item * OIDC_CLAIM_preferred_username

=back

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Groups are assumed to be a comma-separated string.

=item *

No validation of tokens is performed.

=item *

Relies entirely on upstream authentication.

=back

=head1 INCOMPATIBILITIES

=head1 AUTHOR

Avnish Pratap Singh <as74@sanger.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2026 Genome Research Ltd

This file is part of NPG software.

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
