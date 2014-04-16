#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::util;

use strict;
use warnings;
use base qw(ClearPress::util Exporter);
use Readonly;

our $VERSION = '0';

Readonly::Scalar my $MAIL_DOMAIN       => q(sanger.ac.uk);
Readonly::Scalar my $DEFAULT_DATA_PATH => q(data);
Readonly::Scalar my $UNIX_YEAR_DELTA   => 1900;

sub dbname { my $self = shift; return $self->config->val($self->dbsection(), 'dbname') || q(npg); }
sub dbhost { my $self = shift; return $self->config->val($self->dbsection(), 'dbhost') || q(localhost); }
sub dbport { my $self = shift; return $self->config->val($self->dbsection(), 'dbport') || q(3306); }
sub dbuser { my $self = shift; return $self->config->val($self->dbsection(), 'dbuser') || q(root); }
sub dbpass { my $self = shift; return $self->config->val($self->dbsection(), 'dbpass') || q(); }

sub yearmonthday {
  my ($t1, $t2, $t3, $day, $month, $year) = localtime;
  $year += $UNIX_YEAR_DELTA;
  $month++;
  $month = sprintf '%02d', $month;
  $day   = sprintf '%02d', $day;
  return "$year$month$day";
}

sub cleanup {
  my $self = shift;
  $self->dbh->disconnect();
  delete $self->{dbh};
  return $self->SUPER::cleanup();
}

sub data_path {
  my $root = $DEFAULT_DATA_PATH;
  if ($ENV{'NPG_DATA_ROOT'}) {
    ($root) = $ENV{'NPG_DATA_ROOT'} =~ m{([a-z0-9/\._\-]+)}ixms;
  }
  return $root;
}

sub dbsection {
  return $ENV{'dev'} ? $ENV{'dev'} : 'live';
}

sub decription_key {
  my $self = shift;
  return $self->config->val($self->dbsection(), 'decription_key');
}

sub mail_domain {
  return $MAIL_DOMAIN;
}

1;

__END__

=head1 NAME

npg::util - A database handle and utility object

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 mail_domain - Retrieve the local site mail domain

  my $mail_domain = $oUtil->mail_domain();

=head2 data_path - path to data directory containing config.ini and templates subdirectory

  my $sPath - $oUtil->data_path();

=head2 dbsection - 'dev' or 'live' or 'test' based on environment

  my $sEnv = $oUtil->dbsection();

=head2 dbname - Accessor for configuration's database name

  my $sDBName = $oUtil->dbname();

=head2 dbhost - Accessor for configuration's database host

  my $sDBHost = $oUtil->dbhost();

=head2 dbuser - Accessor for configuration's database user

  my $sDBUser = $oUtil->dbuser();

=head2 dbpass - Accessor for configuration's database password

  my $sDBPass = $oUtil->dbpass();

=head2 dbport - Accessor for configuration's database port

  my $sDBPort = $oUtil->dbport();

=head2 decription_key - returns configuration's decription key

=head2 yearmonthday - method for getting a string in the format yyyymmdd

  my $yearmonthday = $oUtil->yearmonthday();

=head2 cleanup - post-request cleanup (database disconnection)

  $oUtil->cleanup();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item ClearPress::util

=item Exporter

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013 GRL, by Roger Pettett

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
