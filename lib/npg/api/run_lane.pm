#########
# Author:        rmp
# Created:       2007-03-28
# copied from: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg/api/run_lane.pm, r16046
#
package npg::api::run_lane;
use strict;
use warnings;
use base qw(npg::api::base);
use Carp;
use npg::api::run;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 16046 $ =~ /(\d+)/smx; $r; };

__PACKAGE__->mk_accessors(fields());

sub fields {
  return qw(id_run_lane id_run tile_count tracks position );
}

sub new_from_xml {
  my ($self, $pkg, $xmlfrag, $util) = @_;
  my $child = $self->SUPER::new_from_xml($pkg, $xmlfrag, $util);

  if($pkg eq 'npg::api::run_lane') {
    $util = $child->util();
    $child->{run} = npg::api::run->new({
					util   => $util,
					id_run => $xmlfrag->getAttribute('id_run'),
				       });
  }

  return $child;
}

sub run {
  my $self = shift;

  if(!$self->{run}) {
    $self->{run} = npg::api::run->new({
				       util   => $self->util(),
				       id_run => $self->id_run(),
				      });
  }
  return $self->{run};
}

sub get {
  my ($self, $field) = @_;

  if(!exists $self->{$field}) {
    if( (exists $self->{id_run}) and
        (exists $self->{position}) and
        not (exists $self->{id_run_lane})
      ){
      %{$self} = %{(grep{$_->position == $self->{position}}@{$self->run()->run_lanes()})[0]};
    }
  }

  return $self->SUPER::get($field);
}

sub lims {
  my $self  = shift;

  if(!$self->{lims}) {
    my $lims = $self->run()->lims();
    if ($lims) {
      $self->{'lims'} = $lims->associated_child_lims_ia->{$self->position()};
    }
  }
  return $self->{'lims'};
}

sub is_library {
  my $self = shift;
  my $l = $self->lims;
  return $l && (!$l->is_control && !$l->is_pool) ? 1 : 0;
}

sub is_control {
  my $self = shift;
  my $l = $self->lims;
  return $l && $l->is_control ? 1 : 0;
}

sub is_pool {
  my $self = shift;
  my $l = $self->lims;
  return ($l && $l->is_pool) ? 1 : 0;
}

sub asset_id {
  my $self = shift;
  my $l = $self->lims;
  return $l ? $l->library_id : undef;
}

sub contains_nonconsented_human {
  my $self = shift;
  my $l = $self->lims();
  if ($l) {
    return $l->contains_nonconsented_human;
  }
  return 0;
}
*contains_unconsented_human = \&contains_nonconsented_human; #Backward compat

sub is_spiked_phix {
   my $self = shift;
   my $lims = $self->lims();
   return ($lims && defined $lims->spiked_phix_tag_index) ? 1 : 0;
}

sub manual_qc {
  my $self  = shift;
  my $lims = $self->lims();
  my $manual_qc = undef;
  if ($lims && defined $lims->seq_qc_state) {
    $manual_qc = $lims->seq_qc_state ? 'pass' : 'fail';
  }
  return $manual_qc;
}

1;
__END__

=head1 NAME

npg::api::run_lane - An interface onto npg.run_lane

=head1 VERSION

$Revision: 16046 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - constructor inherited from npg::api::base

=head2 new_from_xml - handling of denormalized service data for run_lanes

  my $oRunLane = npg::api::run_lane->new_from_xml('npg::api::run_lane', $sXMLFragment);

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::api::<pkg>->fields();

=head2 id_run_lane - Get/set accessor: primary key of this object

  my $iIdRunLane = $oRunLane->id_run_lane();
  $oRunLane->id_run_lane($i);

=head2 id_run - Get/set accessor: ID of the run to which this lane belongs

  my $iIdRun = $oRunStatus->id_run();
  $oRunStatus->id_run($i);

=head2 position - Get/set accessor: position of this lane on the flowcell

  my $iPosition = $oRunLane->position();
  $oRunLane->position($i);

=head2 tile_count - Get/set the tile count on this lane

  my $iTileCount = $oRunLane->tile_count();
  $oRunLane->tile_count($iTileCount);

=head2 tracks - Get/set the number of imaging columns (tracks) on this lane

  my $iTracks = $oRunLane->tracks();
  $oRunLane->tracks($iTracks);

=head2 position - Get/set the lane position of this lane on the flowcell (library batch)

  my $iPosition = $oRunLane->position();

=head2 manual_qc - Get the manual QC for this lane on the flowcell

  my $sManualQC = $oRunLane->manual_qc();

=head2 run - npg::api::run this lane is on

  my $oRun = $oRunLane->run();

=head2 lims - st::api::lims object corresponding to this lane

=head2 asset_id

=head2 is_library - returns a boolean value indicating whether this lane is a simple library, as oppesed to being a control lane or a pool

=head2 is_control - returns a boolean value indicating whether this lane is used as a control lane

=head2 is_pool - returns a boolean value indicating whether this lane is a pool

=head2 get - overridden get accessor from npg::api::base

Uses information in run XML if id_run_lane is unknown but id_run and position are known.
  
=head2 is_spiked_phix - check this lane is spiked phix or not

=head2 contains_nonconsented_human
  
=head2 contains_unconsented_human - (backward omcpat alias for contains_nonconsented_human)
  
=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item npg::api::base

=item Carp

=item npg::api::run

=item st::api::lims

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
