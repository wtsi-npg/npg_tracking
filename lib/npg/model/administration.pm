package npg::model::administration;

use strict;
use warnings;
use base qw(npg::model);
use npg::model::user;
use npg::model::usergroup;

our $VERSION = '0';

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

=head1 SYNOPSIS

  model to sit behind npg::view::administration, with methods for display items

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 users - fetches arrayref of all users

=head2 usergroups - fetches arrayref of all user groups

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item npg::model

=item npg::model::user

=item npg::model::usergroup

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger M Pettett

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2020 Genome Research Ltd.

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
