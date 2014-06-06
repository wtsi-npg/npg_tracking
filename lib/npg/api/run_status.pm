#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::api::run_status;
use strict;
use warnings;
use base qw(npg::api::base);
use Carp;
use npg::api::run;

our $VERSION = '0';


__PACKAGE__->mk_accessors(fields());
__PACKAGE__->hasa('run');

sub fields {
  return qw(id_run_status id_run date id_run_status_dict id_user iscurrent description);
}

1;
__END__

=head1 NAME

npg::api::run_status - An interface onto npg.run_status

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - constructor inherited from npg::api::base

  Takes optional util.

  my $oRunStatus = npg::api::run_status->new();

  my $oRunStatus = npg::api::run_status->new({
    'id_run_status' => $iIdRunStatus,
    'util'          => $oUtil,
  });


  my $oRunStatus = npg::api::run_status->new({
    'id_run'             => $iIdRun,
    'id_run_status_dict' => $iIdRunStatus,
   #'date', 'id_user' and 'iscurrent' are omitted for creation as the web application sets them
  });
  $oRunStatus->create();

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::api::<pkg>->fields();

=head2 id_run_status - Get/set accessor: primary key of this object

  my $iIdRunStatus = $oRunStatus->id_run_status();
  $oRunStatus->id_run_status($i);

=head2 id_run - Get/set accessor: ID of the run to which this status belongs

  my $iIdRun = $oRunStatus->id_run();
  $oRunStatus->id_run($i);

=head2 date - Get/set accessor: date of this status

  my $sDate = $oRunStatus->date();
  $oRunStatus->date($s);

=head2 id_run_status_dict - Get/set accessor: dictionary type ID of this status

  my $iIdRunStatusDict = $oRunStatus->id_run_status_dict();
  $oRunStatus->id_run_status_dict($i);

=head2 id_user - Get/set accessor: user ID of the operator for this status

  my $iIdUser = $oRunStatus->id_user();
  $oRunStatus->id_user($i);

=head2 iscurrent - Get accessor: whether or not this status is current for its run

  my $bIsCurrent = $oRunStatus->iscurrent();
  $oRunStatus->iscurrent($b);

=head2 description - Get accessor: the description of this status from its dictionary type ID

  my $sDescription = $oRunStatus->description();

=head2 run - npg::api::run to which this status belongs

  my $oRun = $oRunStatus->run();

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
