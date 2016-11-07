#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::api::instrument_status;
use strict;
use warnings;
use base qw(npg::api::base);
use Carp;
use English qw{-no_match_vars};
use npg::api::instrument;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields(), 'name');
__PACKAGE__->hasa(qw(instrument));

sub fields {
  return qw(id_instrument_status id_instrument date id_instrument_status_dict id_user iscurrent description comment);
}

1;
__END__

=head1 NAME

npg::api::instrument_status - An interface onto npg.instrument_status

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - constructor inherited from npg::api::base

  Takes optional util.

  my $oInstrumentStatus = npg::api::instrument_status->new();

  my $oInstrumentStatus = npg::api::instrument_status->new({
    'id_instrument_status' => $iIdInstrumentStatus,
    'util'          => $oUtil,
  });

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::api::<pkg>->fields();

=head2 id_instrument_status - Get/set accessor: primary key of this object

  my $iIdInstrumentStatus = $oInstrumentStatus->id_instrument_status();
  $oInstrumentStatus->id_instrument_status($i);

=head2 id_instrument - Get/set accessor: ID of the instrument to which this status belongs

  my $iIdInstrument = $oInstrumentStatus->id_instrument();
  $oInstrumentStatus->id_instrument($i);

=head2 date - Get/set accessor: date of this status

  my $sDate = $oInstrumentStatus->date();
  $oInstrumentStatus->date($s);

=head2 id_instrument_status_dict - Get/set accessor: dictionary type ID of this status

  my $iIdInstrumentStatusDict = $oInstrumentStatus->id_instrument_status_dict();
  $oInstrumentStatus->id_instrument_status_dict($i);

=head2 id_user - Get/set accessor: user ID of the operator for this status

  my $iIdUser = $oInstrumentStatus->id_user();
  $oInstrumentStatus->id_user($i);

=head2 iscurrent - Get accessor: whether or not this status is current for its instrument

  my $bIsCurrent = $oInstrumentStatus->iscurrent();
  $oInstrumentStatus->iscurrent($b);

=head2 comment - Get accessor: the comment of this status from its dictionary type ID

  my $sComment = $oInstrumentStatus->comment();

=head2 instrument - npg::api::instrument to which this status belongs

  my $oInstrument = $oInstrumentStatus->instrument();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

npg::api::base

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
