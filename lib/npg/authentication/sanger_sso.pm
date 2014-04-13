# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-28

package npg::authentication::sanger_sso;

use strict;
use warnings;
use Exporter qw( import );
use Crypt::CBC;
use MIME::Base64;
use CGI;
use Carp;
use Readonly;

our $VERSION = '0';

our @EXPORT_OK = qw(sanger_cookie_name sanger_username);

Readonly::Scalar our $COOKIE_NAME  => 'WTSISignOn';

sub sanger_cookie_name {
  return $COOKIE_NAME;
}

sub sanger_username {
  my ($cookie, $enc_key) = @_;
  my $username = q[];
  my $at_domain = q[];
  if ($cookie && $enc_key) {
    # Alternatively: use URI::Escape; my $decoded = uri_unescape($cookie);
    my $unescaped = CGI::unescape($cookie);
    ##no critic (RequireDotMatchAnything)
    $unescaped =~ s/\ /+/mxg;
    ##use critic
    my $decoded = decode_base64($unescaped);
    my $crypt = Crypt::CBC->new(  -key         => $enc_key,
                                  -literal_key => 1,
                                  -cipher      => 'Blowfish',
                                  -header      => 'randomiv',
                                  -padding     => 'space');
    my $decrypted = $crypt->decrypt($decoded);
    ($username, $at_domain) = $decrypted =~ /<<<<(\w+)(@[\w|\.]+)?/xms;
    if ($username && $at_domain) {
      $username .= $at_domain;
    }
  }
  return $username;
}

1;
__END__

=head1 NAME

  npg::authentication::sanger_sso

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

Module to extract username from WTSI single sign-on cookie value

=head1 SUBROUTINES/METHODS

=head2 sanger_cookie_name

=head2 sanger_username

Called by Catalyst authentication infrastructure....

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Crypt::CBC

=item MIME::Base64

=item CGI

=item Readonly

=item Exporter qw(import)

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David Jackson

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2012 GRL, by Jennifer Liddle (js10@sanger.ac.uk)

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
