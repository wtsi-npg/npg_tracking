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

sub site_header {
  return q[];
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

=head2 username
  Accessor for username, returns an empty string by default.

=head2 cgi

=head2 site_header
  In the parent object this methods defines the start, including
  the head part, of the HTML page. In this application the start
  of the page is defined in the actions.tt2 template, which is
  rendered by Clearpress before the template associated with a
  particular HTML view. Therefore, in this application this
  method returns an empty string.  

=head2 footer
  Closing HTML tags of NPG tracking HTML pages.

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

Copyright (C) 2009,2017 GRL, by Andy Brown, David K Jackson

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
