#########
# Author:        rmp
# Created:       2007-03-28
#

package npg::controller;
use strict;
use warnings;

use base qw(ClearPress::controller);

use npg::decorator;

use npg::model::instrument_format;
use npg::model::manufacturer;
use npg::model::instrument;
use npg::model::instrument_annotation;
use npg::model::instrument_utilisation;
use npg::model::instrument_status;
use npg::model::run;
use npg::model::run_lane;
use npg::model::run_status;
use npg::model::run_annotation;
use npg::model::user;
use npg::model::user2usergroup;
use npg::model::usergroup;
use npg::model::search;
use npg::model::administration;
use npg::model::run_lane_annotation;
use npg::model::instrument_status_annotation;
use npg::model::usage;

use npg::view::annotation;
use npg::view::manufacturer;
use npg::view::instrument_format;
use npg::view::instrument_status;
use npg::view::instrument_annotation;
use npg::view::instrument_utilisation;
use npg::view::instrument;
use npg::view::instrument_mod;
use npg::view::run_status_dict;
use npg::view::run_annotation;
use npg::view::run_status;
use npg::view::run_lane;
use npg::view::run;
use npg::view::error;
use npg::view::user;
use npg::view::user2usergroup;
use npg::view::usergroup;
use npg::view::search;
use npg::view::administration;
use npg::view::run_lane_annotation;
use npg::view::intensity;
use npg::view::instrument_status_annotation;
use npg::view::usage;

our $VERSION = '0';

sub session {
  my ($self, $util) = @_;
  if($self->{session}) {
    return $self->{session};
  }

  my $session   = $self->decorator($util)->session();
  my $pkg       = $util->config->val('application', 'namespace');
  my $appname   = $pkg || $ENV{SCRIPT_NAME};
  $session->{$appname} ||= {};
  $self->{session} = $session->{$appname};

  return $self->{session};
}

sub decorator {
  my ($self, $util) = @_;

  if($self->{decorator}) {
    return $self->{decorator};
  }
  my $decorator   = npg::decorator->new({ cgi => $util->cgi(),});
  #########
  # support unauthenticated pipeline user
  #
  if(!$decorator->username() && $util->cgi->param('pipeline')) {
    #########
    # Casually bypass all security for pipeline purposes.
    # Should probably be coupled with a hostname test for il\d+\-win or il\d+proc
    # Or IP-based restrictions
    #
    $decorator->username('pipeline');
  } else {
    $decorator->username(lc $decorator->username());
  }
  $self->{decorator} = $decorator;
  return $decorator;
}

1;
__END__

=head1 NAME

npg::controller - NPG tracking controller

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 session - SangerWeb-specific session grabber

=head2 decorator - creates/returns a decorator object for the application

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item CGI

=item Carp

=item ClearPress::controller

=item English -no_match_vars

=item POSIX strftime

=item base

=item npg::decorator

=item npg::model::administration

=item npg::model::instrument

=item npg::model::instrument_format

=item npg::model::manufacturer

=item npg::model::run

=item npg::model::run_annotation

=item npg::model::run_lane

=item npg::model::run_lane_annotation

=item npg::model::run_status

=item npg::model::search

=item npg::model::usage

=item npg::model::user

=item npg::model::user2usergroup

=item npg::model::usergroup

=item npg::view::administration

=item npg::view::error

=item npg::view::instrument

=item npg::view::instrument_format

=item npg::view::instrument_mod

=item npg::view::instrument_status

=item npg::view::intensity

=item npg::view::manufacturer

=item npg::view::run

=item npg::view::run_annotation

=item npg::view::run_lane

=item npg::view::run_lane_annotation

=item npg::view::run_status

=item npg::view::run_status_dict

=item npg::view::search

=item npg::view::usage

=item npg::view::user

=item npg::view::user2usergroup

=item npg::view::usergroup

=item strict

=item warnings

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
