#########
# Author:        rmp
# Created:       2008-03
#
package npg::model::instrument_mod_dict;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());

sub fields {
  return qw(id_instrument_mod_dict
            description
            revision);
}

sub instrument_mod_dicts {
  my $self  = shift;
  my $dbh   = $self->util->dbh();
  my $pkg   = ref $self;
  my $query = q{SELECT * FROM instrument_mod_dict ORDER BY description, revision};
  return $self->gen_getarray($pkg, $query);
}

sub descriptions {
  my $self  = shift;
  my $dbh   = $self->util->dbh();
  my $query = q{SELECT DISTINCT description FROM instrument_mod_dict ORDER BY description};
  return $dbh->selectall_arrayref($query, {});
}

1;
__END__

=head1 NAME

npg::model::instrument_mod_dict

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 instrument_mod_dicts - Arrayref of npg::model::instrument_mod_dicts

  my $arRunStatusDicts = $oRunStatusDict->instrument_mod_dicts();

=head2 descriptions - fetches arrayref of existing instrument mod description types

  my $adescriptions = $oInstrumentModDict->descriptions();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

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
