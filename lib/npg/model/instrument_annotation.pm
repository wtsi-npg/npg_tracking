package npg::model::instrument_annotation;

use strict;
use warnings;
use English qw(-no_match_vars);
use Carp;

use base qw(npg::model);

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_a([qw(instrument annotation)]);

sub fields {
  return qw(id_instrument_annotation
            id_instrument
            id_annotation);
}

sub create {
  my $self       = shift;
  my $annotation = $self->annotation();
  my $util       = $self->util();
  my $tr_state   = $util->transactions();

  $util->transactions(0);

  ########
  # only try to create or update if it hasn't come from run_annotation create
  if (!$self->{from_run_anno}) {
    #########
    # create or update
    #
    $annotation->save();
  }

  $self->{id_annotation} = $annotation->id_annotation();
  $self->SUPER::create(); # We create this row here, so that the event table
                          # can receive the correct info

  my $event = npg::model::event->new({
    util                    => $util,
    entity_type_description => 'instrument_annotation',
    event_type_description  => 'annotation',
    entity_id               => $self->id_instrument_annotation(),
    description => $annotation->user->username() . q{ annotated instrument } .
      $self->instrument->name() . qq{\n} . $annotation->comment(),
  });
  $event->create();

  #########
  # re-enable transactions for final create
  #
  $util->transactions($tr_state);

  $util->transactions() and $util->dbh->commit();

  return 1;
}

1;
__END__

=head1 NAME

npg::model::instrument_annotation

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 instrument - npg::model::instrument for this instrument_annotation

  my $oInstrument = $oInstrumentAnnotation->instrument();

=head2 annotation - npg::model::annotation for this instrument_annotation

  my $oAnnotation = $oRunAnnotation->annotation();

=head2 create - coordinate saving the annotation and the instrument_annotation link

  $oRunAnnotation->create();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Roger Pettett

=item Marina Gourtovaia

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007-2012,2013,2014,2025 Genome Research Ltd.

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
