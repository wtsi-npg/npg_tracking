#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2006-10-31
# Last Modified: $Date: 2012-12-17 14:00:36 +0000 (Mon, 17 Dec 2012) $
# Id:            $Id: util.pm 16335 2012-12-17 14:00:36Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg/util.pm $
#
package npg::util;
use strict;
use warnings;
use Carp;
use base qw(ClearPress::util Exporter);

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 16335 $ =~ /(\d+)/smx; $r; };

Readonly::Scalar my $MAIL_DOMAIN => q(sanger.ac.uk);

##no critic (RegularExpressions::RequireDotMatchAnything RegularExpressions::RequireExtendedFormatting RegularExpressions::RequireLineBoundaryMatching RegularExpressions::ProhibitUnusualDelimiters ValuesAndExpressions::ProhibitMagicNumbers BuiltinFunctions::ProhibitLvalueSubstr ValuesAndExpressions::ProhibitEmptyQuotes ControlStructures::ProhibitPostfixControls ValuesAndExpressions::ProhibitNoisyQuotes)

sub mail_domain {
  return $MAIL_DOMAIN;
}

sub dbname { my $self = shift; return $self->config->val($self->dbsection(), 'dbname') || q(npg); }
sub dbhost { my $self = shift; return $self->config->val($self->dbsection(), 'dbhost') || q(localhost); }
sub dbport { my $self = shift; return $self->config->val($self->dbsection(), 'dbport') || q(3306); }
sub dbuser { my $self = shift; return $self->config->val($self->dbsection(), 'dbuser') || q(root); }
sub dbpass { my $self = shift; return $self->config->val($self->dbsection(), 'dbpass') || q(); }

sub yearmonthday {
  my $self = shift;
  my ($t1, $t2, $t3, $day, $month, $year) = localtime;
  Readonly::Scalar my $UNIX_YEAR_DELTA => 1900;

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
  my $self = shift;
  return $self->data_root() . '/prodsoft/npg';
}

sub decription_key {
  my $self = shift;
  return $self->config->val($self->dbsection(), 'decription_key');
}

########################
# Methods below are borrowed from SangerWeb.pm
# 
sub data_root {
  my ($self, $devlive) = @_;
  my $str              = $self->_server_root() . '/data/';
  return $self->_devlive($str, $devlive);
}

sub _document_root {
  my ($self, $devlive) = @_;
  my ($root)           = $ENV{'DOCUMENT_ROOT'} =~ m|([a-z0-9/\._\-]+)|i;
  return $self->_devlive($root, $devlive);
}

sub _server_root {
  my ($self, $devlive) = @_;
  my $root             = $self->_document_root();
  substr($root, -1, 1) = '' if(substr($root, -1, 1) eq '/'); # strip trailing slash
  $root                =~ s|^(.*)/[^/]+|$1|; # strip trailing directory (usually htdocs)
  return $self->_devlive($root, $devlive);
}

sub _devlive {
  my ($self, $str, $devlive) = @_;
  $devlive ||= '';

  if($devlive eq 'live') {
    $str =~ s!/WWW(dev|test|live)?/!/WWWlive/!smg;
  } elsif($devlive eq 'dev') {
    $str =~ s!/WWW(dev|test|live)?/!/WWWdev/!smg;
  }
  return $str;
}

1;

__END__

=head1 NAME

npg::util - A database handle and utility object

=head1 VERSION

$Revision: 16335 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 mail_domain - Retrieve the local site mail domain

  my $mail_domain = $oUtil->mail_domain();

=head2 data_path - path to data directory containing config.ini and templates subdirectory

  my $sPath - $oUtil->data_path();

=head2 dbsection - 'dev' or 'live' based on environment

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

=head2 dbh - A database handle for the supported database

  my $oDbh = $oUtil->dbh();

=head2 yearmonthday - method for getting a string in the format yyyymmdd

  my $yearmonthday = $oUtil->yearmonthday();

=head2 data_root

=head2 cleanup - post-request cleanup (database disconnection)

  $oUtil->cleanup();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Carp

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
