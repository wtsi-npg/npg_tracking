#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::model::instrument_format;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::instrument;
use npg::model::manufacturer;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_a(q[manufacturer]);
__PACKAGE__->has_many(q[instrument]);
__PACKAGE__->has_all();

sub fields {
  return qw(id_instrument_format
            id_manufacturer
            model
            iscurrent
            default_tiles
            default_columns
            days_between_washes
            runs_between_washes
           );
}

sub init {
  my $self = shift;

  if($self->{'model'} &&
     !$self->{'id_instrument_format'}) {
    my $query = q(SELECT id_instrument_format
                  FROM   instrument_format
                  WHERE  model = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->model());

    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{'id_instrument_format'} = $ref->[0]->[0];
    }
  }
  return 1;
}

sub current_instrument_formats {
  my $self = shift;

  if(!$self->{'current_instrument_formats'}) {
    my $pkg   = 'npg::model::instrument_format';
    my $query = qq(SELECT @{[join q(, ), $pkg->fields()]}
                   FROM   @{[$pkg->table()]}
                   WHERE  iscurrent = 1);
    $self->{'current_instrument_formats'} =  $self->gen_getarray($pkg,
                                                                $query);
  }

  return $self->{'current_instrument_formats'};
}

sub instrument_formats_sorted {
  my $self = shift;
  my @if = sort { $a->model cmp $b->model} @{$self->instrument_formats};
  return \@if;
}

sub current_instruments {
  my $self  = shift;

  if(!$self->{'current_instruments'}) {
    my $pkg   = 'npg::model::instrument';
    my $query = qq(SELECT @{[join q(, ), $pkg->fields()]}
                   FROM   @{[$pkg->table()]}
                   WHERE  id_instrument_format = ?
                   AND    iscurrent            = 1);
    $self->{'current_instruments'} =  $self->gen_getarray($pkg,
                                                          $query,
                                                          $self->id_instrument_format());
  }

  return $self->{'current_instruments'};
}

sub instrument_count {
  my $self  = shift;
  my $query = q(SELECT COUNT(*)
                FROM   instrument
                WHERE  id_instrument_format = ?);
  my $ref = [];
  eval {
    $ref = $self->util->dbh->selectall_arrayref($query, {},
                                                $self->id_instrument_format());
  } or do {
    carp $EVAL_ERROR;
    return;
  };

  return $ref->[0]->[0] || q(0);
}

sub is_used_sequencer_type {
  my ( $self ) = @_;
  my $types = {'HiSeq'  => 'HiSeq',
               'MiSeq'  => 'MiSeq',
               'HiSeqX' => 'HiSeqX',
               'HK'     => 'GAII',
              };
  return $types->{$self->model()};
}

sub _obtain_numerical_name_part {
  my ( $self, $name ) = @_;
  my ($letters, $numbers) = $name =~ /\A([A-Z]+)(\d+)\z/ixms;
  return $numbers;
}

sub current_instruments_by_format {
  my ( $self ) = @_;

  if ( ! $self->{current_instruments_by_format} ) {
    my $href = {};
    foreach my $format ( @{ $self->current_instrument_formats() } ) {
      my $model = $format->model();
      $model = $model eq q{HK} ? q{GA-II} : $model;
      my @ordered = map  { $_->[0] }
                    sort { $a->[1] <=> $b->[1] }
                    map  { [ $_, $self->_obtain_numerical_name_part( $_->name() ) ] } @{ $format->current_instruments() };
      if ( scalar @ordered ) {
        $href->{$model} = \@ordered;
      }
    }
    $self->{current_instruments_by_format} = $href;
  }

  return $self->{current_instruments_by_format};
}

1;
__END__

=head1 NAME

npg::model::instrument_format

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 init

initialise an object based on model being provided

=head2 manufacturer - npg::model::manufacturer of instruments of this instrument_format

  my $oManufacturer = $oInstrumentformat->manufacturer();

=head2 instruments - Arrayref of npg::model::instruments of this instrument_format

  my $arInstruments = $oInstrumentFormat->instruments();

=head2 current_instruments - Arrayref of npg::model::instruments with iscurrent=1

  my $arCurrentInstruments = $oInstrumentFormat->current_instruments();

=head2 instrument_formats - Arrayref of all instrument_formats (for all manufacturers)

  my $arInstrumentFormats = $oInstrumentFormat->instrument_formats();

=head2 current_instrument_formats - Arrayref of current instrument_formats

  my $arCurrentInstrumentFormats = $oInstrumentFormat->current_instrument_formats();

=head2 instrument_count - count of instruments of this instrument_format

  my $iInstrumentCount = $oInstrumentFormat->instrument_count();

=head2 is_used_sequencer_type

This method returns the instrument type the format is commonly known as if this is a used sequence type, otherwise undef

  my $sIsUsedSequencerType = $oInstrumentFormat->is_used_sequencer_type();

=head2 current_instruments_by_format

Returns a hash ref containing keys of current formats (which have current instruments associated) each pointing to an arrayref of their current instruments

  my $hCurrentInstrumentsByFormat = $oInstrumentFormat->current_instruments_by_format();

=head2 instrument_formats_sorted

  returns instrument format objects array sorted by model name

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

=item npg::model::manufacturer

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
