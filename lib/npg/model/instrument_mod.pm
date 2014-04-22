#########
# Author:        rmp
# Created:       2008-03
#
package npg::model::instrument_mod;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::instrument;
use npg::model::instrument_mod_dict;

our $VERSION = '0';

__PACKAGE__->has_a('instrument_mod_dict');

__PACKAGE__->mk_accessors(fields());

sub fields {
  return qw(id_instrument_mod
            id_instrument
            id_instrument_mod_dict
            date_added
            date_removed
            id_user
            iscurrent);
}

sub user {
  my $self = shift;
  return $self->gen_getobj('npg::model::user');
}

sub instrument {
  my $self = shift;
  return npg::model::instrument->new({
                                      util          => $self->util(),
                                      id_instrument => $self->id_instrument(),
                                    });
}

sub instrument_mod_dict {
  my $self = shift;
  return npg::model::instrument_mod_dict->new({
                                              util => $self->util(),
                                              id_instrument_mod_dict => $self->id_instrument_mod_dict(),
                                              });
}

sub instruments {
  my $self = shift;
  my $util = $self->util();
  return $self->instrument->instruments();
}

sub instrument_mod_dicts {
  my $self = shift;
  return npg::model::instrument_mod_dict->new({util => $self->util()})->instrument_mod_dicts();
}

1;
__END__

=head1 NAME

npg::model::instrument_mod

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 instrument - npg::model::instrument to which this mod is attached

  my $oInstrument = $oInstrumentMod->instrument();

=head2 instrument_mod_dict - npg::model::instrument_mod_dict the type of mod this is

  my $oInstrumentModDict = $oInstrumentMod->instrument_mod_dict();

=head2 user - identifies the user, returning a user object

  my $oUser = $oInstrumentMod->user();

=head2 instruments - fetches array of all instrument objects

  my $aInstruments = $oInstrumentMod->instruments();

=head2 instrument_mod_dicts - fetches array of all instrument_mod_dict objects

  my $aInstrumentModDicts = $oInstrumentMod->instrument_mod_dicts();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item npg::model

=item English

=item Carp

=item npg::model::instrument

=item npg::model::instrument_mod_dict

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 GRL, by Andy Brown

This file is part of NPG.

NPG is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/ .

=cut
