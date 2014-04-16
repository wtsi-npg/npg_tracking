#########
# Author:        ajb
# Created:       2008-04-24
#
package npg::model::administration;
use strict;
use warnings;
use English qw(-no_match_vars);
use Carp;
use base qw(npg::model);
use npg::model::user;
use npg::model::usergroup;
use npg::model::instrument_mod_dict;

our $VERSION = '0';

sub instrument_mod_dict_descriptions {
  my $self = shift;
  return npg::model::instrument_mod_dict->new({util => $self->util()})->descriptions();
}

sub users {
  my $self = shift;
  return npg::model::user->new({util => $self->util()})->users();
}

sub usergroups {
  my $self = shift;
  return npg::model::usergroup->new({util => $self->util()})->usergroups();
}

1;
__END__

=head1 NAME

npg::model::administration

=head1 VERSION

=head1 SYNOPSIS

  model to sit behind npg::view::administration, with methods for display items

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 instrument_mod_dict_descriptions - fetches arrayref of existing instrument modification description types

  my $aInstrument_mod_dict_descriptions = $oAdministration->instrument_mod_dict_descriptions();

=head2 users - fetches arrayref of all users

=head2 usergroups - fetches arrayref of all user groups

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item English

=item Carp

=item base

=item npg::model

=item npg::model::user

=item npg::model::usergroup

=item npg::model::instrument_mod_dict

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger M Pettett

=head1 LICENSE AND COPYRIGHT

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
