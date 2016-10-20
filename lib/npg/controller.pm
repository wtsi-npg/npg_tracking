package npg::controller;

use strict;
use warnings;
use base qw(ClearPress::controller);

use npg::decorator;

use npg::model::instrument_format;
use npg::model::manufacturer;
use npg::model::instrument;
use npg::model::instrument_annotation;
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
use npg::view::instrument;
use npg::view::instrument_mod;
use npg::view::run_status_dict;
use npg::view::run_annotation;
use npg::view::run_status;
use npg::view::run_lane;
use npg::view::run;
use npg::view::user;
use npg::view::user2usergroup;
use npg::view::usergroup;
use npg::view::search;
use npg::view::administration;
use npg::view::run_lane_annotation;
use npg::view::instrument_status_annotation;
use npg::view::usage;

our $VERSION = '0';

sub session {
  my ($self, $util) = @_;

  if(!$self->{'session'}) {
    my $session   = $self->decorator($util)->session();
    my $pkg       = $util->config->val('application', 'namespace');
    my $appname   = $pkg || $ENV{SCRIPT_NAME};
    $session->{$appname} ||= {};
    $self->{'session'} = $session->{$appname};
  }

  return $self->{'session'};
}

sub decorator {
  my ($self, $util) = @_;

  if(!$self->{'decorator'}) {
    $self->{'decorator'} = npg::decorator->new({ cgi => $util->cgi(),});
  }
  return $self->{'decorator'};
}

1;
__END__

=head1 NAME

npg::controller - NPG tracking controller

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 session

=head2 decorator

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item ClearPress::controller

=item base

=item strict

=item warnings

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger M Pettett

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL

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
