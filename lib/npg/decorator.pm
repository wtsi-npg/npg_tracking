#########
# Author:        ajb
# Created:       2009-04-15
#
package npg::decorator;
use strict;
use warnings;
use base qw(ClearPress::decorator);

our $VERSION = '0';

sub username {
  my ($self, $username) = @_;
  if ($username) {
    $self->{username} = $username;
  }
  return $self->{username} || q{};
}

sub cgi {
  my ($self, $cgi) = @_;
  if ($cgi) {
    $self->{cgi} = $cgi;
  }
  return $self->{cgi} || undef;
}

sub header {
  return qq[Content-type: text/html\n\n];
}

sub footer {
  return qq[</div></body></html>\n];
}

1;
__END__

=head1 NAME

npg::decorator - NPG tracking decorator

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 username - accessor for username, but which returns an empty string instead of undef by default

=head2 cgi

=head2 header

=head2 footer

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item ClearPress::decorator

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2009 GRL, by Andy Brown

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
