#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::model::instrument_status_dict;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::instrument_status;
use Readonly;

our $VERSION = '0';

Readonly::Hash our %SHORT_DESCRIPTIONS => {
                  'down'             => 'down',
                  'request approval' => 'requ',
                  'up'               => 'up',
                  'wash required'    => 'wash',
                  'wash in progress'     => 'wash',
                  'wash performed'   => 'wash',
                  'planned maintenance'   => 'plan',
                  'planned repair'   => 'pl_r',
                  'planned service'  => 'pl_s',
                  'down for repair'  => 'dn4r',
                  'down for service' => 'dn4s',
                                          };

__PACKAGE__->mk_accessors(fields());

sub fields {
  return qw(id_instrument_status_dict
            description
            iscurrent);
}

sub init {
  my $self = shift;

  if($self->{'description'} &&
     !$self->{'id_instrument_status_dict'}) {
    my $query = q(SELECT id_instrument_status_dict
                  FROM   instrument_status_dict
                  WHERE  description = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->description());

    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{'id_instrument_status_dict'} = $ref->[0]->[0];
    }
  }
  return 1;
}

sub instrument_status_dicts {
  my $self = shift;
  return $self->gen_getall();
}

sub instruments {
  my $self = shift;
  if(!$self->{'instruments'}) {
    my $pkg   = 'npg::model::instrument';
    my $query = qq(SELECT @{[join q(, ), map { "i.$_ AS $_" } $pkg->fields()]}
                   FROM   @{[$pkg->table()]} i,
                          instrument_status  i_s
                   WHERE  i_s.id_instrument = i.id_instrument
                   AND    i_s.iscurrent     = 1
                   AND    i_s.id_instrument_status_dict = ?);

    $self->{'instruments'} = $self->gen_getarray($pkg, $query, $self->id_instrument_status_dict());
  }
  return $self->{'instruments'};
}

1;
__END__

=head1 NAME

npg::model::instrument_status_dict

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 init - support load-by-description

  $oInstrumentStatusDict->init();

  e.g.
  my $oRSD = npg::model::instrument_status_dict->new({
      'util'        => $oUtil,
      'description' => 'pending',
  });

  print $oRSD->id_instrument_status_dict();

=head2 instrument_status_dicts - Arrayref of npg::model::instrument_status_dicts

  my $arInstrumentStatusDicts = $oInstrumentStatusDict->instrument_status_dicts();

=head2 instruments - Arrayref of npg::model::instruments with a current status having this id_instrument_status_dict

  my $arInstruments = $oInstrumentStatusDict->instruments();

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

=item npg::model::instrument_status

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
