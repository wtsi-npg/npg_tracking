# Author:        marina.gourtovaia@sanger.ac.uk
# Created:       15 March 2012

package npg::authentication::sanger_ldap;

use strict;
use warnings;
use Exporter qw( import );
use Net::LDAP;
use English qw(-no_match_vars);
use Carp;
use Readonly;

our $VERSION = '0';

our @EXPORT_OK = qw(person_info);  # symbols to export on request

Readonly::Scalar our $SANGER_LDAP_SERVER => 'ldap.internal.sanger.ac.uk';
Readonly::Scalar our $LDAP_SEARCH_BASE   => 'ou=people,dc=sanger,dc=ac,dc=uk';

sub person_info {
  my $username = shift;

  my $info = {name => q[], team => q[],};
  if (!$username) {
    warn qq[Warning: cannot retrieve person info from LDAP server since username is not given.\n];
    return $info;
  }

  my $ldap=Net::LDAP->new($SANGER_LDAP_SERVER) or croak qq[Cannot connect to LDAP server $SANGER_LDAP_SERVER: $EVAL_ERROR];
  $ldap->bind; # anonymous
  my $mesg=$ldap->search(base => $LDAP_SEARCH_BASE,
                         filter => "(&(sangerActiveAccount=TRUE)(sangerRealPerson=TRUE)(|(uid=$username)))",
                         attrs => ['sn', 'givenName', 'cn', 'departmentNumber']  #jpegPhoto attr also available
                        );
  $mesg->code && croak qq[LDAP error when searching for $username: ] . $mesg->error;
  my @entries=$mesg->entries();
  if (scalar @entries == 1) {
    my $entry = $entries[0];
    my $sn = $entry->get_value('sn') || q[];
    my $gn = $entry->get_value('givenName') || q[];
    my $cn = $entry->get_value('cn') || q[];
    if($cn ne $gn . q[ ] . $sn) {
      $cn =~ s/\s+.*$//smx;
      $gn .= ' (' . $cn . ')';
    }
    my $realname = join q[ ], $gn, $sn;
    $realname =~ s/^\s+//smx;
    $realname =~ s/\s+$//smx;
    if ($realname) {
      $info->{name} = $realname;
    }
    my $team = $entry->get_value('departmentNumber');
    if ($team) {
      $info->{team} = $team;
    }
  }

  $ldap->unbind;
  return $info;
}
1;
__END__

=head1 NAME

  npg::authentication::sanger_ldap

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

Module to extract username from WTSI single sign-on cookie value

=head1 SUBROUTINES/METHODS

=head2 person_info

 Return a hash ref with the following keys defined: name, team. Any of these values can be empty strings.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Net::LDAP;

=item English qw(-no_match_vars)

=item Readonly

=item Exporter qw( import )

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2012 GRL, by Marina Gourtovaia (mg8@sanger.ac.uk)

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
