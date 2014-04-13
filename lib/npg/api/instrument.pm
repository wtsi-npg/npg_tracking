#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::api::instrument;
use strict;
use warnings;
use English qw(-no_match_vars);
use base qw(npg::api::base);
use Carp;
use DBI;
use npg::api::instrument_status;
use npg::api::designation;
use npg::api::run;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->hasmany([qw(run instrument_status)]);
__PACKAGE__->hasa({current_instrument_status => 'instrument_status'});

sub fields {
  return qw(id_instrument
            name
            id_instrument_format
            external_name
            serial
            iscurrent
            ipaddr
            instrument_comp
            mirroring_host
            staging_dir
            model
            latest_contact);
}

sub instruments {
  my $self        = shift;
  my $instruments = $self->list->getElementsByTagName('instruments')->[0];
  my $pkg         = ref $self;

  $self->{instruments} = [map { $self->new_from_xml($pkg, $_); } $instruments->getElementsByTagName('instrument')];

  return $self->{instruments};
}

sub new_from_xml {
  my ($self, $pkg, $xml_frag ) = @_;
  my $obj = $self->SUPER::new_from_xml($pkg, $xml_frag);

  my $designations = $xml_frag->getElementsByTagName('designations')->[0];
  if ($designations) {
    $obj->{designations} = [map { $self->SUPER::new_from_xml('npg::api::designation', $_); } $designations->getElementsByTagName('designation')];
  }

  return $obj;
}

sub designations {
  my $self = shift;

  if($self->{designations}) {
    return $self->{designations};
  }

  my $designations = $self->read->getElementsByTagName('designations')->[0];
  my $desig_list = [ map { $self->SUPER::new_from_xml('npg::api::designation', $_); }
                    $designations->getElementsByTagName('designation')
                   ];

  $self->{designations} = [];

  foreach my $i ( @{$desig_list} ) {
    push @{$self->{designations}}, $i->{'description'};
  }

  return $self->{designations};
}

1;
__END__

=head1 NAME

npg::api::instrument - An interface onto npg.instrument

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - constructor inherited from npg::api::base

  Takes optional util for overriding the service base_uri.

  my $oInstrument = npg::api::instrument->new();

  my $oInstrument = npg::api::instrument->new({
    'id_instrument' => $iIdInstrument,
    'util'          => $oUtil,
  });

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::api::<pkg>->fields();

=head2 id_instrument - Get/set the ID of this instrument

  my $iInstrument = $oInstrument->id_instrument();
  $oInstrument->id_instrument($iIdInstrument);

=head2 name - Get/set the name of this instrument, e.g. IL12

  my $iInstrumentName = $oInstrument->name();
  $oInstrument->name($iIdInstrumentName);

=head2 id_instrument_format - Get/set the id_instrument_format (major type of this instrument)

  my $iInstrumentFormat = $oInstrument->id_instrument_format();
  $oInstrument->id_instrument_format($iIdInstrumentFormat);

=head2 external_name - Get/set the external name (e.g. EACS12)

  my $sExtName = $oInstrument->external_name();
  $oInstrument->external_name($sExtName);

=head2 serial - Get/set the serial number of this instrument

  my $sSerial = $oInstrument->serial();
  $oInstrument->serial($sSerial);

=head2 iscurrent - Get/set whether this instrument is current

  my $bIsCurrent = $oInstrument->iscurrent();
  $oInstrument->iscurrent($bIsCurrent);

=head2 current_instrument_status - the current npg::api::instrument_status for this instrument

  my $oCurrentInstrumentStatus = $oInstrument->current_instrument_status();

=head2 instrument_statuses - arrayref of npg::api::instrument_statuses

  my $arInstrumentStatuses = $oInstrument->instrument_statuses();

=head2 instruments - arrayref of npg::api::instruments

  my $arInstruments = $oInstrument->instruments();

=head2 runs - arrayref of npg::api::runs for this instrument

  my $arRuns = $oInstrument->runs();

=head2 new_from_xml - Wrapper for base::new_from_xml. Populates designations for each instrument.

=head2 designations - Arrayref of designations for this instrument

  my $arDesignations = $oInstrument->designations();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item npg::api::base

=item Carp

=item DBI

=item English

=item npg::api::instrument_status

=item npg::api::designation

=item npg::api::run

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 GRL, by Roger Pettett

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
