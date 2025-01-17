package npg::view::run;

use strict;
use warnings;
use Carp;
use English qw(-no_match_vars);
use POSIX qw(strftime);
use Socket;

use npg::model::run_status_dict;
use npg::model::instrument;
use npg::model::instrument_format;
use npg::model::run_lane;
use npg::model::run;

use base qw(npg::view);

our $VERSION = '0';

Readonly::Scalar our $PAGINATION_LEN   => 40;
Readonly::Scalar our $PAGINATION_START => 0;
Readonly::Scalar my  $DAYS_IN_WEEK     => 14;
Readonly::Scalar my  $DEFAULT_RUN_STATUS => 'run pending';

sub new {
  my ($class, @args) = @_;
  my $self   = $class->SUPER::new(@args);
  my $model  = $self->model();
  my $util   = $self->util();
  my $cgi    = $util->cgi();

  if($model->id_run() eq 'group') {
    $cgi->param('type', 'group');
    $model->id_run(0);
  }

  my $id_run = $self->model->id_run() || q();
  return $self;
}

sub authorised {
  my $self   = shift;
  my $util   = $self->util();
  my $requestor = $util->requestor();
  my $action = $self->action();
  my $aspect = $self->aspect() || q[];

  #########
  # Allow loaders to create runs.
  #
  if ( ( $aspect eq 'add' || $aspect eq 'add_pair_ajax' ) && $requestor->is_member_of('loaders') ) {return 1;}

  if(  $aspect ne 'update_tags' && $action eq 'create' && $requestor->is_member_of('loaders') ) {
    return 1;
  }

  if (  $aspect eq 'update_tags' && ( $requestor->is_member_of('annotators') || $requestor->is_member_of('pipeline') ) ) {
    return 1;
  }

  if ( $action eq 'update' &&
       ( $requestor->is_member_of('loaders') || $requestor->is_member_of('manual_qc') ) ) {
    return 1;
  }

  if (  $aspect eq q{list_stuck_runs} && ( $requestor->is_member_of( q{loaders} ) || $requestor->is_member_of( q{annotators} ) || $requestor->is_member_of( q{manual_qc} ) ) ) {
    return 1;
  }

  return $self->SUPER::authorised();
}

sub read { ## no critic (ProhibitBuiltinHomonyms)
  my $self  = shift;
  my $model = $self->model();
  if(!$model->id_instrument()){
    croak q{This run not registered: }.$model->id_run;
  }

  #########
  # Override id_run_pair (which will be empty for R1) using the id_run of any
  # existing second end
  #
  $model->{id_run_pair} = $model->run_pair() ? $model->run_pair->id_run() : 0;

  return 1;
}

sub add {
  my $self            = shift;
  my $util            = $self->util();
  my $cgi             = $util->cgi();
  my $model           = $self->model();
  my $id_run          = $cgi->param('id_run');        # Duplicate existing run
  my $id_instrument   = $cgi->param('id_instrument'); # New for instrument
  my $instrument      = npg::model::instrument->new({
                 util          => $util,
                 id_instrument => $id_instrument,
                });
  my $instruments = $instrument->current_instruments();

  #########
  # Try and figure out if this page is being accessed from an instrument and
  # if so, which one.
  #

  if($id_run) {
    #########
    # If we're duplicating a run, take the instrument from that one
    #
    $model = npg::model::run->new({
           util   => $util,
           id_run => $id_run,
          });
    $self->model($model);
    $id_instrument = $model->id_instrument();
    $instrument    = $model->instrument();

  } else {

    #########
    # We're not duplicating a run.
    # First see if we can determine instrument from its IP address
    # Access from the sequencers is via a proxy which sets X-F-F request header
    #
    $id_instrument = $model->location_is_instrument( $instrument );

  }

  if($id_instrument) {
    $model->id_instrument($id_instrument);
  }

  $model->{instruments} = $instruments;
  return 1;
}

sub add_pair_ajax {
  my $self          = shift;
  my $util          = $self->util();
  my $cgi           = $util->cgi();
  my $model         = $self->model();
  my $batch_id      = $cgi->param('batch_id');
  my $id_instrument = $cgi->param('id_instrument');
  if($batch_id){
    $model->{batch_id} = $batch_id;
  }
  if($id_instrument) {
    $model->id_instrument($id_instrument);
  }
  return 1;
}

sub list {
  my $self       = shift;
  my $util       = $self->util();
  my $cgi        = $util->cgi();

  my $model      = $self->model();
  my $batch_id = $cgi->param('batch_id');

  if ( $batch_id ) { # Most likely this request comes from the search utility.
    $model->{runs} = $model->runs_on_batch($batch_id);
  } else {

    my $params = {};
    for my $p (qw/len start
                  id_instrument_format id_instrument manufacturer
                  id_run_status_dict/) {
      $params->{$p} = $cgi->param($p);
    }
    $params->{len} ||= $PAGINATION_LEN;
    $params->{start} ||= $PAGINATION_START;
    $params->{id_instrument_format} ||= $npg::model::instrument_format::SHOW_ALL_PARAM_VALUE;
    $params->{manufacturer} ||= $npg::model::instrument_format::DEFAULT_MANUFACTURER_NAME;

    if ( !$params->{id_run_status_dict} ) {
      $params->{id_run_status_dict} = npg::model::run_status_dict->new({
        util        => $util,
        description => $DEFAULT_RUN_STATUS,
      })->id_run_status_dict();
    }

    $model->{runs} = $model->runs($params);
    $model->{count_runs} = $model->count_runs($params);

    $model->{id_run_status_dict} = $params->{id_run_status_dict};
    $model->{start} = $params->{start};
    $model->{len}   = $params->{len};
    $model->{id_instrument_format} = $params->{id_instrument_format};
    $model->{manufacturer} = $params->{manufacturer};
    if ($params->{id_instrument}) { # For 'Runs' tab on an instrument page.
      $self->{no_main_menu} = 1;
      $model->{id_instrument} = $params->{id_instrument};
    }
  }

  return 1;
}

sub list_summary {
  my $self       = shift;
  my $util       = $self->util();
  my $days       = $self->selected_days();
  my $model      = $self->model();
  $model->{days} = $days;

  return 1;
}

sub selected_days {
  my $self = shift;
  my $days;
  if ($self->util->cgi->param('days')) {
    ($days) = $self->util->cgi->param('days') =~ /(\d+)/smx;
  }
  return $days || $DAYS_IN_WEEK;
}

sub create {
  my ($self, @args) = @_;
  my $util        = $self->util();
  my $cgi         = $util->cgi();
  my $model       = $self->model();
  my $tracks      = $cgi->param('tracks');

  my $paired_read = $cgi->param('paired_read');
  my $multiplex_run = $cgi->param('multiplex_run');
  $self->model->{paired_read} = $paired_read;
  $self->model->{multiplex_run} = $multiplex_run;
  # radio button selection for flowcell slots (if any)
  $self->model->{fc_slot} = $cgi->param('fc_slot');
  $self->model->{team} = $cgi->param('team');

  $self->model->{library_names} = $cgi->param('library_names') || q({});
  $self->model->{study_names} = $cgi->param('study_names') || q({});

  my %read_cycle_count = map {$_=>$cgi->param('read_cycle_'.$_)} map  { my ($c) = $_ =~ /^read_cycle_(\d+)/smx }
                    grep { $_ =~ /^read_cycle_\d+/smx } $cgi->param();
  $self->model->{read_cycle_count} = \%read_cycle_count;

  my @id_lanes    = map  { my ($p) = $_ =~ /^lane_(\d+)_tile_count/smx }
                    grep { $_ =~ /^lane_\d+_tile_count/smx } $cgi->param();

  my $lanes     = {};
  for my $p (@id_lanes) {
    my $tile_count = $cgi->param("lane_${p}_tile_count");
    if($tile_count) {
      $lanes->{$p} = $tile_count;
    }
  }

  $model->{'run_lanes'} = [map {
         npg::model::run_lane->new({
                  'util'             => $util,
                  'tile_count'       => $lanes->{$_},
                  'tracks'           => $tracks,
                  'position'         => $_,
                 });
             }
         sort { $a <=> $b } keys %{$lanes}];

  #########
  # Fake the cgi id_user parameter based on requestor's id_user
  # so that model::run->create is able to find it for its new xrun_status
  #
  $model->id_user($util->requestor->id_user());
  return $self->SUPER::create(@args);
}

sub update_tags {
  my $self = shift;
  my $cgi = $self->util->cgi();
  my $dbh = $self->util->dbh();
  my (@tags, @specified_tags);
  if ($cgi->param('tags')) { @tags = map { lc $_ } split q{ }, $cgi->param('tags'); };
  if ($cgi->param('tagged_already')) { @specified_tags = map { lc $_ } split q{ }, $cgi->param('tagged_already'); };
  my (%tagged_already, %saving_tags, %in_save_box, %removing_tags);

  if ( ! $cgi->param('allow_verified') ) {
    my %verified_tags;
    foreach my $tag ( @tags ) {
      if ( $tag =~ /verified/ixms ) {
        $verified_tags{$tag}++;
      }
    }
    foreach my $tag ( @specified_tags ) {
      if ( $verified_tags{$tag} ) {
        delete $verified_tags{$tag};
      }
    }
    if ( scalar keys %verified_tags ) {
      croak q{You cannot verify a run/flowcell/reagent using the tagging system.<br />Please go back and verify on an instrument using the button};
    }
  }

  for my $tag (@specified_tags) {
    $tagged_already{$tag}++;
  }

  for my $tag (@tags) {
    $in_save_box{$tag}++;
    if ($tagged_already{$tag}) {
      next;
    }
    $saving_tags{$tag}++;
  }

  for my $tag (@specified_tags) {
    if ($in_save_box{$tag}) {
      next;
    }
    $removing_tags{$tag}++;
  }

  my @tags_to_save = sort keys %saving_tags;
  my @tags_to_remove = sort keys %removing_tags;
  my $tr_state = $self->util->transactions();
  $self->util->transactions(0);
  eval {
    if (scalar @tags_to_save) {
      $self->model->save_tags(\@tags_to_save, $self->util->requestor());
    }
    if (scalar @tags_to_remove) {
      $self->model->remove_tags(\@tags_to_remove, $self->util->requestor());
    }
    1;

  } or do {
    $self->util->transactions($tr_state);
    $tr_state and $dbh->rollback();
    croak $EVAL_ERROR . q{rolled back attempt to save info for the tags for run } . $self->model->id_run();
  };

  $self->util->transactions($tr_state);
  $tr_state and $dbh->commit();
  return 1;
}

sub update {
  my ($self, @args) = @_;
  my $util          = $self->util();
  my $cgi           = $util->cgi();
  my $tile_columns  = $cgi->param('tile_columns');
  my $tile_rows     = $cgi->param('tile_rows');

  if($tile_columns && $tile_rows) {
    $util->transactions(0);
    for my $run_lane (@{$self->model->run_lanes()}) {
      $run_lane->tracks($tile_columns);
      $run_lane->tile_count($tile_columns*$tile_rows);
      $run_lane->update();
    }
    $util->transactions(1);
  }

  return $self->SUPER::update(@args);
}

sub list_stuck_runs {
  my ( $self ) = @_;
  return 1;
}

1;

__END__

=head1 NAME

npg::view::run - view handling for runs

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new

=head2 authorised - additional handling for public list_ajax response

=head2 add - handling for run creation view

=head2 add_pair_ajax - handling for connecting paired runs together

=head2 list - handling for runs-by-id_run_status_dict

=head2 list_ajax - list handling for AJAX response

=head2 list_summary - handling for recent run display

=head2 selected_days - factored out obtaining the number of days selected, with default to set to 14

=head2 create - handling for run, run_lanes, and run_status

=head2 read - handling for override id_run_pair (which will be empty for R1) using the id_run of any existing second end

=head2 update_tags - handles incoming request to add/remove tags for the run. Wraps all in a single
       transaction so that all tags are done, or none at all

=head2 update - handling for tile-layout updates

=head2 list_stuck_runs

handling for the stuck runs page

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item npg::view

=item strict

=item warnings

=item Carp

=item English

=item npg::model::run_status_dict

=item npg::model::instrument

=item npg::model::instrument_format

=item npg::model::run_lane

=item npg::model::run

=item POSIX

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Roger Pettett

=item Marina Gourtovaia

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007-2012,2013,2014,2016,2017,2021,2025 Genome Research Ltd.

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
