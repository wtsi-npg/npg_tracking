use utf8;
package npg_tracking::Schema::Result::Instrument;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::Instrument

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<instrument>

=cut

__PACKAGE__->table("instrument");

=head1 ACCESSORS

=head2 id_instrument

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'char'
  default_value: (empty string)
  is_nullable: 0
  size: 32

=head2 id_instrument_format

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 external_name

  data_type: 'char'
  default_value: (empty string)
  is_nullable: 0
  size: 32

=head2 serial

  data_type: 'char'
  default_value: (empty string)
  is_nullable: 0
  size: 128

=head2 iscurrent

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 ipaddr

  data_type: 'char'
  default_value: (empty string)
  is_nullable: 1
  size: 15

=head2 instrument_comp

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 mirroring_host

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=head2 staging_dir

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 latest_contact

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 percent_complete

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id_instrument",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "name",
  { data_type => "char", default_value => "", is_nullable => 0, size => 32 },
  "id_instrument_format",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "external_name",
  { data_type => "char", default_value => "", is_nullable => 0, size => 32 },
  "serial",
  { data_type => "char", default_value => "", is_nullable => 0, size => 128 },
  "iscurrent",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "ipaddr",
  { data_type => "char", default_value => "", is_nullable => 1, size => 15 },
  "instrument_comp",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "mirroring_host",
  { data_type => "varchar", is_nullable => 1, size => 16 },
  "staging_dir",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "latest_contact",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "percent_complete",
  { data_type => "tinyint", extra => { unsigned => 1 }, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_instrument>

=item * L</name>

=back

=cut

__PACKAGE__->set_primary_key("id_instrument", "name");

=head1 UNIQUE CONSTRAINTS

=head2 C<name>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name", ["name"]);

=head1 RELATIONS

=head2 instrument_annotations

Type: has_many

Related object: L<npg_tracking::Schema::Result::InstrumentAnnotation>

=cut

__PACKAGE__->has_many(
  "instrument_annotations",
  "npg_tracking::Schema::Result::InstrumentAnnotation",
  { "foreign.id_instrument" => "self.id_instrument" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 instrument_designations

Type: has_many

Related object: L<npg_tracking::Schema::Result::InstrumentDesignation>

=cut

__PACKAGE__->has_many(
  "instrument_designations",
  "npg_tracking::Schema::Result::InstrumentDesignation",
  { "foreign.id_instrument" => "self.id_instrument" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 instrument_format

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::InstrumentFormat>

=cut

__PACKAGE__->belongs_to(
  "instrument_format",
  "npg_tracking::Schema::Result::InstrumentFormat",
  { id_instrument_format => "id_instrument_format" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 instrument_mods

Type: has_many

Related object: L<npg_tracking::Schema::Result::InstrumentMod>

=cut

__PACKAGE__->has_many(
  "instrument_mods",
  "npg_tracking::Schema::Result::InstrumentMod",
  { "foreign.id_instrument" => "self.id_instrument" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 instrument_statuses

Type: has_many

Related object: L<npg_tracking::Schema::Result::InstrumentStatus>

=cut

__PACKAGE__->has_many(
  "instrument_statuses",
  "npg_tracking::Schema::Result::InstrumentStatus",
  { "foreign.id_instrument" => "self.id_instrument" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 runs

Type: has_many

Related object: L<npg_tracking::Schema::Result::Run>

=cut

__PACKAGE__->has_many(
  "runs",
  "npg_tracking::Schema::Result::Run",
  { "foreign.id_instrument" => "self.id_instrument" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 sensor_data_instruments

Type: has_many

Related object: L<npg_tracking::Schema::Result::SensorDataInstrument>

=cut

__PACKAGE__->has_many(
  "sensor_data_instruments",
  "npg_tracking::Schema::Result::SensorDataInstrument",
  { "foreign.id_instrument" => "self.id_instrument" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 sensor_instruments

Type: has_many

Related object: L<npg_tracking::Schema::Result::SensorInstrument>

=cut

__PACKAGE__->has_many(
  "sensor_instruments",
  "npg_tracking::Schema::Result::SensorInstrument",
  { "foreign.id_instrument" => "self.id_instrument" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:F7mTaj060i1RggPpHSpfXw
# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: mg8 $
# Created:       2010-04-08
# Last Modified: $Date: 2012-11-26 09:53:48 +0000 (Mon, 26 Nov 2012) $
# Id:            $Id: Instrument.pm 16269 2012-11-26 09:53:48Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema/Result/Instrument.pm $

use DateTime;
use DateTime::TimeZone;
use Try::Tiny;
use Carp;
use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 16269 $ =~ /(\d+)/mxs; $r; };

Readonly::Scalar my $HISEQ_INSTR_MODEL => 'HiSeq';
Readonly::Scalar my $MISEQ_INSTR_MODEL => 'MiSeq';
Readonly::Scalar my $CBOT_INSTR_MODEL  => 'cBot';
Readonly::Scalar my $NEW_INSTRUMENT_INITIAL_STATUS => 'wash required';

Readonly::Array  our @CURRENT_RUNS    => ('run pending', 'run in progress', 'run on hold', 'run complete');
Readonly::Array  our @BLOCKING_RUNS   => ('run pending', 'run in progress', 'run on hold');

Readonly::Hash my %STATUS_CHANGE_AUTO => {
  'up' => 'wash required',
  'wash performed'      => 'up',
  'planned maintenance' => 'down for repair',
  'planned repair'      => 'down for repair',
  'planned service'     => 'down for service',
};

=head2 designations

Type: many_to_many

Related object: L<npg_tracking::Schema::Result::Designation>

=cut

__PACKAGE__->many_to_many('designations' => 'instrument_designations', 'designation');

=head2 sensors

Type: many_to_many

Related object: L<npg_tracking::Schema::Result::Sensor>

=cut

__PACKAGE__->many_to_many('sensors' => 'sensor_instruments', 'sensor');

=head2 sensor_data

Type: many_to_many

Related object: L<npg_tracking::Schema::Result::SensorData>

=cut

__PACKAGE__->many_to_many('sensor_data' => 'sensor_data_instruments', 'sensor_data');


=head2 _isd_rs

Create a dbic InstrumentStatusDict result set as shorthand and to access the
row validation methods in that class.

=cut

sub _isd_rs {
    my ($self) = @_;

    return $self->result_source->schema->resultset('InstrumentStatusDict')
                ->new( {} );
}


=head2 _user_rs

Create a dbic User result set as shorthand and to access the row validation
methods in that class.

=cut

sub _user_rs {
    my ($self) = @_;

    return $self->result_source->schema->resultset('User')->new( {} );
}

=head2 insert

Overwrites default insert method; adds a trigger to create a 'wash required'
status for a new sequencing instrument

=cut

sub insert {
    my $self = shift;
    my $result = $self->next::method(@_);
    if ($self->does_sequencing) {
        $self->update_instrument_status( $NEW_INSTRUMENT_INITIAL_STATUS,
            'pipeline', 'initial new instrument status');
    }
    return $result;
}

=head2 current_instrument_status

Return the current instrument status for the row object. Return undef if there
is no current instrument status (or no status at all) for the instrument.

=cut

sub current_instrument_status {
    my ($self) = @_;
    my $crs_rs = $self->instrument_statuses->search({iscurrent => 1,});
    if ($crs_rs->count() == 1) {
      return $crs_rs->next->instrument_status_dict->description();
    }
    return;
}


=head2 update_instrument_status

Change the instrument_status for an instrument. This means adding a new row to
the instrument_status table and setting the iscurrent field to 1, after
marking all the previous rows for the isntrument as iscurrent 0.

Two arguments are required, an instrument status and a user in that order. In
both cases the primary key can be supplied, or the (case-insensitive)
description or username fields respectively.

    $instrument_result_object->update_instrument_status( 4, 'jo3' );
    $instrument_result_object->update_instrument_status( 'Down', 5 );

=cut

sub update_instrument_status {
    my ( $self, $status_identifier, $user_identifier, $comment ) = @_;

    ( defined $comment ) || ( $comment = q{} );

    my $isd_id = $self->_isd_rs->_insist_on_valid_row($status_identifier)->
                    id_instrument_status_dict();

    my $user_id =
        $self->_user_rs->_insist_on_valid_row($user_identifier)->id_user();

    my $old_status_rs = $self->instrument_statuses->search ({iscurrent => 1,});
    my $count = $old_status_rs->count;
    
    if ($count == 1 && $old_status_rs->next->id_instrument_status_dict == $isd_id) {
        return; # Do nothing if the instrument_status is already set and current.
    }

    my $transaction = sub {
      if ($count) {
        $old_status_rs->update( { iscurrent => 0 } );
      }
      if ( $user_id == $self->_user_rs->pipeline_id() ) {
        $comment &&= q{ : } . $comment;     # Separate any previous text.
        $comment = 'automatic status update' . $comment;
      }
      $self->instrument_statuses->create(
            {
                id_instrument             => $self->id_instrument(),
                date                      => DateTime->now(time_zone=> DateTime::TimeZone->new(name => q[local])),
                id_instrument_status_dict => $isd_id,
                id_user                   => $user_id,
                iscurrent                 => 1,
                comment                   => $comment,
            },
      );
    };

    try {
        $self->result_source->schema->txn_do($transaction);
    } catch {
        if ($_ =~ /Rollback failed/) {     # Rollback failed
            croak 'Rollback failed on updating instrument status'; 
        }
    };

    return;
}

=head2 status_to_change_to

Returns a status description for the next automatically 
assigned instrument status. Run status description
argument is optional; should be set if the change is related
to a run status change.

=cut

sub status_to_change_to {
  my ($self, $run_status) = @_;

  if ($self->does_sequencing) {
    my $current = $self->current_instrument_status();
    if (!$current) { return; }
    if (!exists $STATUS_CHANGE_AUTO{$current}) {
      return;
    }
    my $next_auto = $STATUS_CHANGE_AUTO{$current};

    if ( $self->is_idle() &&
      ($current eq 'planned maintenance' ||
       $current eq 'planned repair' ||
       $current eq 'planned service')) {
        return $next_auto;
    }

    if ($current eq 'wash performed' ||
       ($current eq 'up' && $run_status && 
          ( $run_status eq 'run cancelled' ||
            $run_status eq 'run stopped early' ||
            $run_status eq 'run complete'
          ))
        ) {
      return $next_auto;
    }
  }
  return;
}

=head2 autochange_status_if_needed

Automatically changes the status of the instrument to the
next status. Run status description argument should be given.

=cut

sub autochange_status_if_needed {
  my ($self, $run_status, $user_identifier ) = @_;

  if (!$run_status) {
    croak 'Run status needed';
  }
  if ($self->does_sequencing) {
    my $new_instr_status = $self->status_to_change_to($run_status);
    if ($new_instr_status) {
      $self->update_instrument_status( $new_instr_status, $user_identifier);
    }
  }
  return;
}

sub _auto_from_status {
    my ($self, $to) = @_;

    foreach my $from (keys %STATUS_CHANGE_AUTO) {
        if ($STATUS_CHANGE_AUTO{$from} eq $to) {
            return $from; 
        }
    }
    croak "'$to' is not one of the statuses to change to automatically";
}

=head2 set_status_wash_requied_if_needed

Set status to wash required if the wash is due

=cut

sub set_status_wash_requied_if_needed {
    my $self = shift;

    my $days_between_washes = $self->instrument_format->days_between_washes;
    if (!$days_between_washes) {
        return 0;
    }

    my $status = 'wash required';
    my $current_status = $self->current_instrument_status;
    if ($current_status && $current_status ne $self->_auto_from_status($status)) {
        return 0;
    }

    my $latest_wash_row = $self->instrument_statuses->search(
       {
         'instrument_status_dict.description' => 'wash performed',
       },
       {
         join => "instrument_status_dict",
         order_by=>{ -desc => [qw/date/],},
       }
    )->next;

    
    my $latest_wash;
    if ($latest_wash_row) {
        $latest_wash = $latest_wash_row->date;
        $latest_wash->set_time_zone('UTC');
    }

    if (!$latest_wash ||
        DateTime->now()->delta_days($latest_wash)->delta_days() >= $days_between_washes) {
        $self->update_instrument_status(
          $status, 'pipeline', "unwashed for over $days_between_washes days");
        return 1;
    }
    return 0; 
}

=head2 does_sequencing

Returns true for sequencing instruments, false otherwse.

=cut

sub does_sequencing {
  my $self = shift;
  return ($self->instrument_format->model && $self->instrument_format->model ne $CBOT_INSTR_MODEL);
}

=head2 is_idle

Returns true if the instrument is idle, ie has no current
runs associated with it.

=cut

sub is_idle {
    my $self = shift;
    return $self->current_runs->count ? 0 : 1;
}

=head2 blocking_runs

Returns a Run resultset with blocking runs.

=cut

sub blocking_runs {
  my $self  = shift;
  return $self->_runs_with_status(\@BLOCKING_RUNS);
}

=head2 current_runs

Returns a Run resultset with current runs.

=cut

sub current_runs {
  my $self  = shift;
  return $self->_runs_with_status(\@CURRENT_RUNS);
}

sub _runs_with_status {
    my ($self, $run_statuses) = @_;

    return $self->runs->search(
        {
            'run_statuses.iscurrent'      => 1,
            'run_status_dict.description' => {'IN' => $run_statuses},
        },
        {
            join => { 'run_statuses' => 'run_status_dict' },
        },
    );
}

=head1 DESCRIPTION
  DBIx model for an instrument.
  Contains duplicates of functions in npg::model::instrument.
  When editing the code of this module consider if any changes
  are meeded in the other module.

=cut

1;


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
