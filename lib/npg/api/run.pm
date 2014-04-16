#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::api::run;
use strict;
use warnings;
use base qw(npg::api::base);
use Carp;
use English qw{-no_match_vars};
use Scalar::Util qw/weaken/;

use npg::api::run_lane;
use npg::api::run_status;
use npg::api::run_annotation;
use npg::api::instrument;
use st::api::lims;

our $VERSION = '0';

__PACKAGE__->mk_accessors(grep { $_ ne 'id_run' } fields());
__PACKAGE__->hasmany([{annotation => 'run_annotation'}]);
__PACKAGE__->hasa({current_run_status => 'run_status'});
__PACKAGE__->hasmany(['run_status']);

sub fields {
  return qw(id_run
            id_instrument
            priority
            actual_cycle_count
            expected_cycle_count
            id_run_pair
            name
            batch_id
            is_paired
            team
            id_instrument_format
            loading_date
            run_folder);
}

sub is_paired_read{
  my $self = shift;

  if(!exists $self->{is_paired_read}){

    if($self->is_paired_run()){

      $self->{is_paired_read} = 1;
    }else{

      my $tags = $self->tags();
      foreach my $tag (@{$tags}){

        if($tag eq q{paired_read}){

          $self->{is_paired_read} = 1;
          return $self->{is_paired_read};
        }elsif($tag eq q{single_read}){

          $self->{is_paired_read} = 0;
          return $self->{is_paired_read};
        }
      }
      croak 'No data on paired/single read available yet.';
    }
  }

  return $self->{is_paired_read};
}

sub is_paired_run{
  my $self = shift;

  if(!exists $self->{is_paired_run}){

    $self->{is_paired_run} = $self->get(q{is_paired});
  }

  return $self->{is_paired_run};
}

sub is_single_read{
  my $self = shift;

  return !$self->is_paired_read() + 0;
}

sub is_multiplexed {
  my ($self) = @_;
  return $self->has_tag(q{multiplex});
}

sub is_rta {
  my ($self) = @_;
  return $self->has_tag(q{rta});
}

sub having_control_lane {
  my $self = shift;

  foreach my $lane (@{ $self->run_lanes() }){
    if($lane->is_control()){
      return 1;
    }
  }
  return 0;
}
sub has_tag {
  my ($self, $req_tag) = @_;
  my $tags = $self->tags();
  foreach my $tag (@{$tags}) {
    if($tag eq $req_tag) {
      return 1;
    }
  }
  return 0;
}

sub tags{
  my $self = shift;

  if(!$self->{tags}) {

    my $tags_element = $self->read->getElementsByTagName('tags')->[0];

    if(!$tags_element) {

      $self->{tags} = [];
      carp q[Warning: Failed to fetch tags.];
    }else{

      $self->{tags} = [map {$_->getAttribute('description')} $tags_element->getElementsByTagName('tag')];
    }
  }

  return $self->{tags};
}

sub init {
  my $self = shift;

  if($self->{id_run}) {
    ($self->{id_run}) = $self->{id_run} =~ /(\d+)$/smx;
    $self->{id_run} += 0;
  }

  return;
}

sub id_run {
  my ($self, @args) = @_;

  if(!scalar @args) {
    my $ret = $self->SUPER::get('id_run', @args) || q();
    ($ret)  = $ret =~ /(\d+)$/smx;
    $ret   += 0;
    return $ret;

  } else {
    $self->SUPER::set('id_run', @args);
  }

  return $self->SUPER::get('id_run', @args);
}

sub run_pair {
  my $self = shift;

  if(!$self->{'run_pair'}) {
    $self->{'run_pair'} = npg::api::run->new({
                                              'util'   => $self->util(),
                                              'id_run' => $self->id_run_pair(),
                                            });
  }

  return $self->{'run_pair'};
}

sub instrument {
  my $self = shift;

  if(!$self->{instrument}) {
    $self->{instrument} = npg::api::instrument->new({
                                                  util          => $self->util(),
                                                  id_instrument => $self->id_instrument(),
                                                });
  }

  return $self->{instrument};
}

sub run_lanes {
  my $self = shift;

  if(!$self->{run_lanes}) {
    my $run_lanes = $self->read->getElementsByTagName('run_lanes')->[0];

    if(!$run_lanes) {
      croak q[Error: Failed to fetch run_lanes.];#.$run_lanes->asString(1); # pretty print serialised DOM
    }

    ## no critic (ProhibitComplexMappings)
    $self->{run_lanes} = [map { weaken($_->{run}); $_; }
                          map { $_->{run} = $self; $_; }
                          map { npg::api::run_lane->new_from_xml('npg::api::run_lane', $_, $self->util()); }
                          $run_lanes->getElementsByTagName('run_lane')];
  }

  ## use critic
  return $self->{run_lanes};
}

sub run_annotations {
  my ($self, @args) = @_;
  return $self->annotations(@args);
}

sub list_recent {
  my $self       = shift;
  # used somewhere
  my $util       = $self->util();
  my ($obj_type) = (ref $self) =~ /([^:]+)$/smx;
  my $obj_pk     = $self->primary_key();
  my $obj_pk_val = $self->$obj_pk();
  my $obj_uri    = sprintf '%s/%s;list_summary_xml', $util->base_uri(), $obj_type;

  $self->{'list_recent'} = $util->parser->parse_string($util->get($obj_uri,[]));

  my $runs    = $self->{'list_recent'}->getElementsByTagName('runs')->[0];
  my $pkg     = ref $self;

  return [map { $self->new_from_xml($pkg, $_) } $runs->getElementsByTagName('run')];
}

sub recent_running_runs {
  my ($self) = @_;
  # used in instrument_utilisation module
  my $util       = $self->util();
  my ($obj_type) = (ref $self) =~ /([^:]+)$/smx;
  my $obj_uri    = sprintf '%s/%s/recent/running/runs.xml', $util->base_uri(), $obj_type;

  my $xml_obj = $util->parser->parse_string( $util->get($obj_uri, []));
  my @runs    = $xml_obj->getElementsByTagName('run');

  foreach my $run (@runs) {
    my $temp = {};
    $temp->{id_run} = $run->getAttribute('id_run');
    $temp->{start} = $run->getAttribute('start');
    $temp->{end} = $run->getAttribute('end');
    $temp->{id_instrument} = $run->getAttribute('id_instrument');
    $run = $temp;
  }

  return \@runs;
}

sub lims {
  my $self = shift;

  if(!$self->{'lims'} && $self->batch_id()) {
    $self->{'lims'} = st::api::lims->new(id_run   => $self->id_run,
                                         batch_id => $self->batch_id(),
                                        );
  }
  return $self->{'lims'};
}

sub add_tags {
  my ($self, @new_tags) = @_;
  my $util       = $self->util();
  my $id_run     = $self->id_run();
  my @old_tags   = @{$self->tags()};

  if(!$id_run) {
    croak q(Cannot add a tag without an existing run id);
  }

  my $obj_uri = $util->base_uri().qq{/run/$id_run;update_tags};
  my $payload = ['Content_Type' => 'form-data',
                 'Content'      => [
                                      'pipeline'        => 1,
                                      'tags'            => "@new_tags @old_tags",
                                      'tagged_already'  => "@old_tags",
                                   ],
                ];
  my $content = $util->post_non_xml($obj_uri, $payload);
  if($content =~ /Run[ ]$id_run[ ]tagged/smx) {
    carp qq{Run $id_run tagged with @new_tags.};
  }
  return 1;
}

sub remove_tags {
  my ($self, @tags_to_remove) = @_;
  my $util       = $self->util();
  my $id_run     = $self->id_run();
  my @old_tags   = @{$self->tags()};

  my (@new_tags, %tags_to_remove_hash);

  foreach my $tag (@tags_to_remove){
    $tags_to_remove_hash{$tag}++;
  }

  foreach my $tag (@old_tags){
    if(!$tags_to_remove_hash{$tag}){
      push @new_tags, $tag;
    }
  }

  if(!$id_run) {
    croak q(Cannot add a tag without an existing run id);
  }

  my $obj_uri = $util->base_uri().qq{/run/$id_run;update_tags};
  my $payload = ['Content_Type' => 'form-data',
                 'Content'      => [
                                      'pipeline'        => 1,
                                      'tags'            => "@new_tags",
                                      'tagged_already'  => "@old_tags",
                                   ],
                ];
  my $content = $util->post_non_xml($obj_uri, $payload);
  if($content =~ /Run[ ]$id_run[ ]tagged/smx) {
    carp qq{Run $id_run tags removed: @tags_to_remove.};
  }
  return 1;
}

1;
__END__

=head1 NAME

npg::api::run

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - Constructor inherited from npg::api::base

  Takes optional util for overriding the service base_uri.

  my $oRun = npg::api::run->new();

  my $oRun = npg::api::run->new({
    'id_run' => $iIdRun,
    'util'   => $oUtil,
  });

  my $oRun = npg::api::run->new({
    'id_batch'             => $iIdSampleBatch,
    'id_instrument'        => $iIdInstrument,
    'priority'             => $iPriority,
    'actual_cycle_count'   => $iActualCycleCount,
    'expected_cycle_count' => $iExpectedCycleCount,
    'id_run_pair'          => $iIdRunPair,
  });
  $oRun->create();

=head2 init - handling for initialization by run name in id_run

=head2 is_paired - deprecated accessor method, please use is_paired_run instead

=head2 is_paired_run - get method to check the run is paired run or not

=head2 is_paired_read - get method to check the run is paired read or not

=head2 is_single_read - get method to check the run is single read or not

=head2 is_multiplexed - boolean method to check if the run is multiplexed or not

=head2 having_control_lane - check this run having control lane or not

=head2 is_rta - boolean method to check if the run is an rta run or not

=head2 has_tag - boolean return to see if a particular tag is present on a run

  my $bHasTag = $oRun->has_tag($tag);

=head2 tags - return all the associated tags with this run as an arrayref

=head2 add_tags - given a list of tags, add them to the run by http post if the id_run is available

=head2 remove_tags - given a list of tags, remove them from this run by http post

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::api::<pkg>->fields();

=head2 runs - arrayref of npg::api::runs given an optional id_run_status_dict

  my $arRuns = $oRun->runs();
  my $arRuns = $oRun->runs('7');

=head2 id_run - Get/set the id of this run

  my $iIdRun = $oRun->id_run();
  $oRun->id_run($iIdRun);

=head2 id_batch - Get/set the id of the SequenceScape batch on which this run is/was performed

  my $iIdBatch = $oRun->id_batch();
  $oRun->id_batch($iIdBatch);

=head2 id_instrument - Get/set the id of the instrument on which this run is/was performed

  my $iIdInstrument = $oRun->id_instrument();
  $oRun->id_instrument($iIdInstrument);

=head2 priority - Get/set the priority of this run

  my $iPriority = $oRun->priority();
  $oRun->priority($iPriority);

=head2 actual_cycle_count - Get/set the actual number of cycles for this run

  my $iActualCycleCount = $oRun->actual_cycle_count();
  $oRun->actual_cycle_count($iActualCycleCount);

=head2 expected_cycle_count - Get/set the number of expected cycles for this run

  my $iExpectedCycleCount = $oRun->expected_cycle_count();
  $oRun->expected_cycle_count($iExpectedCycleCount);

=head2 id_run_pair - Get/set the id of the run paired with this one

  my $iIdRunPair = $oRun->id_run_pair();
  $oRun->id_run_pair($iIdRunPair);

=head2 name - Get accessor for the name of this run, e.g. IL3_0068

  my $sName = $oRun->name();

=head2 run_pair - An npg::api::run representing this run's pair

  my $oRunPair = $oRun->run_pair();

=head2 instrument - The npg::api::instrument for this run

  my $oInstrument = $oRun->instrument();

=head2 run_lanes - Arrayref of npg::api::run_lanes on this run

  my $arRunLanes = $oRun->run_lanes();

=head2 current_run_status - npg::api::run_status with iscurrent=1

  my $oCurrentRunStatus = $oRun->current_run_status();

=head2 run_annotations - arrayref of npg::api::run_annotations on this run

  my $arAnnotations = $oRun->run_annotations();

=head2 list_recent - arrayref of npg::api::runs with recent status changes

  (within 14 days at time of writing)

  my $arRecentRuns = $oRun->list_recent();

=head2 recent_running_runs - fetch an arrayref of hashrefs that are designated recent runs in NPG - the hashrefs only contain id_run, id_instrument, start and end (end may not be true end of the run on an instrument, as it may be ongoing whilst the method is called)

  my $arRecentRunningRuns - $oRun->recent_running_runs();

=head2 lims  - returns st::api::lims batch-level object for the batch id this run relates to
 
  my $limsObj = $oRun->lims();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

strict

warnings

base

Carp

English

Scalar::Util qw/weaken/

npg::api::run_lane

npg::api::run_status

npg::api::run_annotation

npg::api::instrument

npg::api::base

st::api::lims

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
