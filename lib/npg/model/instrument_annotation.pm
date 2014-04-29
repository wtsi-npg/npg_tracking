#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::model::instrument_annotation;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::annotation;
use npg::model::instrument;
use npg::model::instrument_format;
use npg::model::event;
use npg::model::entity_type;
use Readonly;

our $VERSION = '0';

Readonly::Scalar our $DEFAULT_INSTRUMENT_UPTIME_INTERVAL => 90;

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
  $self->SUPER::create(); # we create this row here, so that the event table can receive the correct info

  my $event = npg::model::event->new({
                                      util                    => $util,
                                      entity_type_description => 'instrument_annotation',
                                      event_type_description  => 'annotation',
                                      entity_id               => $self->id_instrument_annotation(),
                                      description             => $annotation->user->username() . q{ annotated instrument } . $self->instrument->name() . qq{\n} . $annotation->comment(),
                                    });
  $event->create();

  #########
  # re-enable transactions for final create
  #
  $util->transactions($tr_state);

  $util->transactions() and $util->dbh->commit();

  return 1;
}

sub annotations_by_instrument_over_default_uptime {
  my ( $self, $instrument_model ) = @_;
  my $q = q{SELECT i.id_instrument AS id, i.name AS name, a.date AS date, a.comment AS comment, a.id_user as id_user
            FROM instrument i,
            instrument_annotation ia,
            annotation a,
            instrument_format inst_f
            WHERE i.id_instrument = ia.id_instrument
            AND ia.id_annotation = a.id_annotation
            AND a.date > DATE_SUB(NOW(), INTERVAL ? DAY)
            };
  if ( $instrument_model ) {
    $q .= q{AND inst_f.model = ?
            AND inst_f.id_instrument_format = i.id_instrument_format
            };
  }
  $q .= q{ORDER BY i.id_instrument, a.date DESC};

  my $dbh = $self->util->dbh();
  my $sth = $dbh->prepare($q);
  if ( $instrument_model ) {
    $sth->execute( $DEFAULT_INSTRUMENT_UPTIME_INTERVAL, $instrument_model );
  } else {
    $sth->execute($DEFAULT_INSTRUMENT_UPTIME_INTERVAL);
  }

  my $annotations = {};

  while (my $href = $sth->fetchrow_hashref()) {
    push @{$annotations->{$href->{name}}}, $href;
  }
  return $annotations;
}

sub dates_of_annotations_over_default_uptime {
  my ($self, $instrument_model) = @_;
  my $annotations = $self->annotations_by_instrument_over_default_uptime( $instrument_model );

  my $instruments;
  if ( $instrument_model ) {

    $instruments = npg::model::instrument_format->new({
      util => $self->util(),
      model => $instrument_model,
    })->current_instruments();

  } else {
    $instruments = npg::model::instrument->new( {
      util => $self->util(),
    } )->current_instruments();
  }

  my @insts = sort { $a->id_instrument() <=> $b->id_instrument() } @{ $instruments };

  my $dt = DateTime->now();
  my $dt_less_ninety = DateTime->now()->subtract( days => $DEFAULT_INSTRUMENT_UPTIME_INTERVAL );

  my $max_num_annotations = 0;

  foreach my $i (sort keys %{$annotations}) {
    my $num_annotations = scalar @{$annotations->{$i}};
    if ($num_annotations > $max_num_annotations) {
      $max_num_annotations = $num_annotations;
    }
  }

  my $stripe = [];
  my $stripe_annotations = [];
  for my $i (1..$max_num_annotations) {
    push @{$stripe}, [];
    push @{$stripe_annotations}, [];
  }
  my $stripe_index = 0;
  $instruments = [];
  foreach my $i (@insts) {
    next if (!$i->iscurrent());
    push @{$instruments}, $i->name();
    my $stat_index = 0;
    foreach my $array (@{$stripe}) {
      my $date = $annotations->{$i->name()}->[$stat_index]->{date};
      if ($date) {
        $date =~ s/[ ].*//gxms;
        my ($y,$m,$d) = split /-/xms, $date;
        my $temp_dt = DateTime->new({year => $y, month => $m, day => $d});

        $date = $dt_less_ninety->delta_days( $temp_dt )->in_units(q{days});
      }
      $array->[$stripe_index] = $date || undef;
      $stat_index++;
    }
    $stat_index = 0;
    foreach my $array (@{$stripe_annotations}) {
      my $date = $annotations->{$i->name()}->[$stat_index]->{date};
      my $comment = $annotations->{$i->name()}->[$stat_index]->{comment} || q{};
      my $info;
      if ($date) {
        $info = $i->name().q{:}.$date.q{:}.$comment;
      }
      $array->[$stripe_index] = $info || q{};
      $stat_index++;
    }
    $stripe_index++;
  }

  if ( ! scalar @{$stripe} ) {
    $stripe = undef;
  }

  return {instruments => $instruments, data => $stripe, annotations => $stripe_annotations};
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

=head2 annotations_by_instrument_over_default_uptime - obtains from database an array of annotations for each instrument over the default uptime

  my $aAnnotationsByInstrumentOverDefaultUptime = $oRunAnnotation->annotations_by_instrument_over_default_uptime();

=head2 dates_of_annotations_over_default_uptime - returns a hashref data structure for all instruments with a daynum for when an annotation was made, and what is in the annotation

  my $hDatesOfAnnotationsOverDefaultUptime = $oRunAnnotation->dates_of_annotations_over_default_uptime();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

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
