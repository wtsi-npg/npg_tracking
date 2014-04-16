#########
# Author:        rmp
# Created:       2007-03-28
#
package st::api::project;

use strict;
use warnings;
use Carp;
use English qw{-no_match_vars};

use base qw(st::api::base);

__PACKAGE__->mk_accessors(fields());

our $VERSION = '0';

sub live {
    my $self = shift;
    return $self->live_url()  . q{/projects};
}

sub dev {
    my $self = shift;
    return $self->dev_url()   . q{/projects};
}

sub fields { return qw( id name ); }

sub project_cost_code {
  my $self     = shift;
  my $proceject_cost_codes = $self->get('Project cost code') || [];
  return $proceject_cost_codes ->[0];
}

1;
__END__

=head1 NAME

st::api::project - an interface to a project

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - fields in this package

  These all have default get/set accessors.

  my @aFields = $oProject->fields();
  my @aFields = <pkg>->fields();

=head2 dev - development service URL

  my $sDevURL = $oProject->dev();

=head2 live - live service URL

  my $sLiveURL = $oProject->live();

=head2 project_cost_code

  my $project_cost_code = $oProject->project_cost_code;

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item st::api::base

=item strict

=item warnings

=item Carp

=item English

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by gq1

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
