#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::model::manufacturer;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::instrument_format;
use npg::model::instrument;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_many('instrument_format');
__PACKAGE__->has_all();

sub fields {
  return qw(id_manufacturer
            name);
}

sub init {
  my $self = shift;

  if($self->{'name'} &&
     !$self->{'id_manufacturer'}) {
    my $query = q(SELECT id_manufacturer
                  FROM   manufacturer
                  WHERE  name = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->name());

    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(scalar @{$ref}) {
      $self->{'id_manufacturer'} = $ref->[0]->[0];
    }
  }
  return 1;
}

sub current_instruments {
  my $self  = shift;
  my $pkg   = 'npg::model::instrument';
  my $query = qq(SELECT @{[join q(, ), q(ifm.model AS model),
                                       map { "i.$_ AS $_" } $pkg->fields()]}
                 FROM   @{[$pkg->table()]} i,
                        instrument_format  ifm
                 WHERE  i.id_instrument_format = ifm.id_instrument_format
                 AND    ifm.id_manufacturer    = ?
                 AND    ifm.iscurrent          = 1
                 AND    i.iscurrent            = 1
                 ORDER BY i.id_instrument_format DESC);
  return $self->gen_getarray($pkg,
                            $query,
                            $self->id_manufacturer());
}

sub instrument_count {
  my $self  = shift;
  my $query = q(SELECT COUNT(*)
                FROM   instrument        i,
                       instrument_format ifrm
                WHERE  ifrm.id_manufacturer      = ?
                AND    ifrm.id_instrument_format = i.id_instrument_format);
  my $ref = [];
  eval {
    $ref = $self->util->dbh->selectall_arrayref($query, {},
                                               $self->id_manufacturer());
  } or do {
    carp $EVAL_ERROR;
    return;
  };

  return $ref->[0]->[0];
}

1;
__END__

=head1 NAME

npg::model::manufacturer

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 init - overridden base-class loader

  Allows instantiation by-name rather as well as id_manufacturer, e.g.
  my $mfct = npg::model::manufacturer->new({
                                            'util' => $util,
                                            'name' => 'Illumina',
                                           });

=head2 manufacturers - arrayref of all npg::model::manufacturers

  my $arManufacturers = $oManufacturer->manufacturers();

=head2 instrument_formats - arrayref of npg::model::instrument_formats by this manufacturer

  my $arInstrumentFormats = $oManufacturer->instrument_formats();

=head2 current_instruments - arrayref of npg::model::instruments which have iscurrent and whose instrument_formats have iscurrent

  my $arInstruments = $oManufacturer->current_instruments();

=head2 instrument_count - A count of all instruments from this manufacturer

  my $iInstrumentCount = $oManufacturer->instrument_count();

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

=item npg::model::instrument_format

=item npg::model::instrument

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 GRL, by Roger Pettett

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
