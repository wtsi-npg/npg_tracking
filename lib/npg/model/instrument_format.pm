package npg::model::instrument_format;

use strict;
use warnings;
use base qw(npg::model);
use Carp;
use Try::Tiny;
use List::MoreUtils qw(any);
use npg::model::instrument;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());
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
    my $ref = [];
    my $err;
    try {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->model());
    } catch {
      $err = $_;
    };

    if ($err) {
      carp $err;
      return;
    }

    if (@{$ref}) {
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

sub current_instruments_from_lab {
  my $self  = shift;
  my $filter_lab = shift;

  if(!$self->{'current_instruments'}) {
    my $pkg   = 'npg::model::instrument';

    my $query = sprintf q{SELECT %s
                          FROM %s
                          WHERE id_instrument_format = ?
                          AND iscurrent              = 1
                          AND lab                    = '%s'},
                        join(q(, ), $pkg->fields()),
                        $pkg->table(),
                        $filter_lab;

    $self->{'current_instruments'} =  $self->gen_getarray($pkg,
                                                          $query,
                                                          $self->id_instrument_format());
  }

  return $self->{'current_instruments'};
}

sub current_instruments_count {
  my $self  = shift;
  return scalar @{$self->current_instruments()};
}

sub is_recently_used_sequencer_format {
  my ( $self ) = @_;
  return any { $self->model() =~ /^$_/smx } qw/MiSeq NovaSeq HiSeq/;
}

sub _obtain_numerical_name_part {
  my ( $self, $name ) = @_;
  my ($letters, $numbers) = $name =~ /\A([A-Z]+)(\d+)\z/ixms;
  return $numbers;
}

sub current_instruments_by_format {
  my $self = shift;

  my $cgi = $self->util()->cgi();
  my $filter_lab = $cgi->param('filter_lab');

  if ( ! $self->{current_instruments_by_format} ) {
    $self->{current_instruments_by_format} =
      $self->_map_current_instruments_by_format($filter_lab);
  }

  return $self->{current_instruments_by_format};
}

sub _map_current_instruments_by_format {
  my ($self, $filter_lab) = @_;

  my $href = {};
  foreach my $format ( @{ $self->current_instrument_formats() } ) {
    my $model = $format->model();
    $model = $model eq q{HK} ? q{GA-II} : $model;
    my $instruments = $filter_lab ?
      $format->current_instruments_from_lab($filter_lab) :
      $format->current_instruments();
    if (@{$instruments}) {
      my @ordered =
        map  { $_->[0] }
        sort { $a->[1] <=> $b->[1] }
        map  { [ $_, $self->_obtain_numerical_name_part( $_->name() ) ] }
        @{$instruments};
      $href->{$model} = \@ordered;
    }
  }

  return $href;
}

sub manufacturer_name {
  my $self = shift;

  my $name;
  my $id_manufacturer = $self->id_manufacturer;
  if( $id_manufacturer ) {
    my $query = qq(SELECT name
                   FROM   manufacturer
                   WHERE  id_manufacturer = $id_manufacturer);
    my $ref;
    try {
      $ref = $self->util->dbh->selectrow_arrayref($query);
    } catch {
      carp $_;
    };

    if($ref and @{$ref}) {
      $name = $ref->[0];
    }
  }

  return $name;
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

=head2 manufacturer_name - the name of the manufacturer of this instrument format

  my $oManufacturer = $oInstrumentformat->manufacturer_name();

=head2 instruments - Arrayref of npg::model::instruments of this instrument_format

  my $arInstruments = $oInstrumentFormat->instruments();

=head2 current_instruments - Arrayref of npg::model::instruments with iscurrent=1

  my $arCurrentInstruments = $oInstrumentFormat->current_instruments();

=head2 current_instruments_from_lab - Arrayref of npg::model::instruments with iscurrent=1 and from a lab

  my $lab = "Sulston"
  my $arCurrentSulstonInstruments = $oInstrumentFormat->current_instruments_from_lab($lab);

=head2 instrument_formats - Arrayref of all instrument_formats (for all manufacturers)

  my $arInstrumentFormats = $oInstrumentFormat->instrument_formats();

=head2 current_instrument_formats - Arrayref of current instrument_formats

  my $arCurrentInstrumentFormats = $oInstrumentFormat->current_instrument_formats();

=head2 current_instruments_count - count of instruments of this instrument_format

  my $iCurrentInstrumentCount = $oInstrumentFormat->current_instrument_count();

=head2 is_recently_used_sequencer_format

Returns true if the instrument format is a recently used sequencing
instrument, otherwise returns false.

  my $is_recent_sequencer = $obj->is_recently_used_sequencer_format();

=head2 current_instruments_by_format

Returns a hash ref containing keys of current formats (which have current instruments associated) each pointing to an arrayref of their current instruments

  my $hCurrentInstrumentsByFormat = $oInstrumentFormat->current_instruments_by_format();

=head2 instrument_formats_sorted

Returns an array of  instrument format objects sorted by model name.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item npg::model

=item Carp

=item Try::Tiny

=item List::MoreUtil

=item npg::model::instrument

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Roger Pettett

=item Marina Gourtovaia

=item Michael Kubiak

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2006,2008,2013,2014,2016,2018,2021,2023 Genome Research Ltd.

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
