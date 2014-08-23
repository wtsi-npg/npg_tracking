use utf8;
package npg_tracking::Schema::Result::Run;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::Run

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

=head1 TABLE: C<run>

=cut

__PACKAGE__->table("run");

=head1 ACCESSORS

=head2 id_run

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_instrument

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 priority

  data_type: 'tinyint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 actual_cycle_count

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 expected_cycle_count

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 id_run_pair

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 is_paired

  data_type: 'tinyint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 batch_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 id_instrument_format

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 flowcell_id

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=head2 folder_name

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=head2 folder_path_glob

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 team

  data_type: 'char'
  is_nullable: 0
  size: 10

=cut

__PACKAGE__->add_columns(
  "id_run",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "id_instrument",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "priority",
  {
    data_type => "tinyint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "actual_cycle_count",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "expected_cycle_count",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "id_run_pair",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "is_paired",
  {
    data_type => "tinyint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "batch_id",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "id_instrument_format",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "flowcell_id",
  { data_type => "varchar", is_nullable => 1, size => 64 },
  "folder_name",
  { data_type => "varchar", is_nullable => 1, size => 64 },
  "folder_path_glob",
  { data_type => "varchar", is_nullable => 1, size => 256 },
  "team",
  { data_type => "char", is_nullable => 0, size => 10 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_run>

=back

=cut

__PACKAGE__->set_primary_key("id_run");

=head1 RELATIONS

=head2 instrument

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::Instrument>

=cut

__PACKAGE__->belongs_to(
  "instrument",
  "npg_tracking::Schema::Result::Instrument",
  { id_instrument => "id_instrument" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
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

=head2 mail_run_project_follower

Type: might_have

Related object: L<npg_tracking::Schema::Result::MailRunProjectFollower>

=cut

__PACKAGE__->might_have(
  "mail_run_project_follower",
  "npg_tracking::Schema::Result::MailRunProjectFollower",
  { "foreign.id_run" => "self.id_run" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 run_annotations

Type: has_many

Related object: L<npg_tracking::Schema::Result::RunAnnotation>

=cut

__PACKAGE__->has_many(
  "run_annotations",
  "npg_tracking::Schema::Result::RunAnnotation",
  { "foreign.id_run" => "self.id_run" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 run_lanes

Type: has_many

Related object: L<npg_tracking::Schema::Result::RunLane>

=cut

__PACKAGE__->has_many(
  "run_lanes",
  "npg_tracking::Schema::Result::RunLane",
  { "foreign.id_run" => "self.id_run" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 run_statuses

Type: has_many

Related object: L<npg_tracking::Schema::Result::RunStatus>

=cut

__PACKAGE__->has_many(
  "run_statuses",
  "npg_tracking::Schema::Result::RunStatus",
  { "foreign.id_run" => "self.id_run" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 runs_read

Type: has_many

Related object: L<npg_tracking::Schema::Result::RunRead>

=cut

__PACKAGE__->has_many(
  "runs_read",
  "npg_tracking::Schema::Result::RunRead",
  { "foreign.id_run" => "self.id_run" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 st_caches

Type: has_many

Related object: L<npg_tracking::Schema::Result::StCache>

=cut

__PACKAGE__->has_many(
  "st_caches",
  "npg_tracking::Schema::Result::StCache",
  { "foreign.id_run" => "self.id_run" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tag_runs

Type: has_many

Related object: L<npg_tracking::Schema::Result::TagRun>

=cut

__PACKAGE__->has_many(
  "tag_runs",
  "npg_tracking::Schema::Result::TagRun",
  { "foreign.id_run" => "self.id_run" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2014-02-28 12:00:59
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:30KwQYdLD+H3KvJKLf9OxQ

# Created:       2010-04-08

our $VERSION = '0';

use Carp;
use Try::Tiny;
use Readonly;

with qw/
         npg_tracking::Schema::Retriever
       /;

Readonly::Hash my %STATUS_CHANGE_AUTO    => (
  'analysis complete'  => 'qc review pending',
);

Readonly::Hash my %STATUS_PROPAGATE_AUTO => (
  'analysis complete'  => 'analysis complete',
  'manual qc complete' => 'archival pending',
);

=head2 tags

Type: many_to_many

Related object: L<npg_tracking::Schema::Result::Tag>

=cut

__PACKAGE__->many_to_many('tags' => 'tag_runs', 'tag');

=head2 BUILD

Post-constructor: try to ensure instrument format is set for run.

=cut

sub BUILD {
    my $self = shift;
    if ($self->id_instrument and not $self->id_instrument_format){
        $self->id_instrument_format($self->instrument->id_instrument_format);
    }
}

=head2 _event_type_rs

Create a dbic EventType result set as shorthand and to access the row
validation methods in that class.

=cut

sub _event_type_rs {
    my ($self) = @_;

    return $self->result_source->schema->resultset('EventType')->new( {} );
}

=head2 _tag_rs

Create a dbic Tag result set as shorthand and to access the row validation
methods in that class.

=cut

sub _tag_rs {
    my ($self) = @_;

    return $self->result_source->schema->resultset('Tag')->new( {} );
}

=head2 _user_rs

Create a dbic User result set as shorthand and to access the row validation
methods in that class.

=cut

sub _user_rs {
    my ($self) = @_;

    return $self->result_source->schema->resultset('User')->new( {} );
}

=head2 current_run_status_description

Return the current run status description for the row object. Return undef if there is no
current run status (or no status at all) for the run.

=cut

sub current_run_status_description {
    my ($self) = @_;

    my $crs = $self->current_run_status();

    if($crs){
      return $crs->description();
    }
    return;
}

=head2 current_run_status

Return the current run status (object) for the row object. Return undef if there is no
current run status (or no status at all) for the run.

=cut

sub current_run_status {
  my ( $self ) = @_;
  return $self->run_statuses()->search({iscurrent => 1})->first(); #not nice - would like this defined by a relationship
}

=head2 update_run_status

Creates a new run status for this run and, if appropriate, marks this
status as current and all the previous statuses as not current.

The description of the status is required.

    $run_row->update_run_status('some status');

If there exists a status with this description that has the same timestamp
or is current and has an earlier timestamp, a new status is not created.

The current status is switched to the new one if the new status is not older
than the current one.

For a new current status a new event row is created and, if appropriate,
instrument status gets changed. In some cases, the run status is automatically
advanced one step further.

An optional username can be supplied. If omitted, the pipeline user is
assumed

    $run_row->update_run_status( 'ArcHIVal pEnding', 'sloppy' );

An optional third argument, a DateTime object, can be supplied. If omitted,
current local time is used.

    $run_row->update_run_status( 'ArcHIVal pEnding', 'sloppy', $date_obj );

Returns undefined if the status has not been saved, otherwise returns the
the new row, which can have iscurrent value set to either 1 or 0.

=cut

sub update_run_status {
    my ( $self, $description, $user_identifier, $date ) = @_;

    $date ||= $self->get_time_now();
    if ( ref $date ne 'DateTime' ) {
        croak '"date" argument should be a DateTime object';
    }

    if ($self->status_is_duplicate($description, $date)) {
      return;
    }

    my $current_status_rs = $self->related_resultset( q{run_statuses} )->search(
              { iscurrent => 1,},
              { order_by => { -desc => 'date'},},
    );

    my $current_status_row = $current_status_rs->next;
    my $make_new_current = $self->current_status_is_outdated($current_status_row, $date);

    my $use_pipeline_user = 1;
    my $user_id = $self->get_user_id($user_identifier, $use_pipeline_user);

    # Use transaction in case iscurrent flag has to be reset
    my $transaction = sub {
        if ($current_status_row && $make_new_current) {                               
            $current_status_rs->update_all( {iscurrent => 0} );
        }
        return $self->related_resultset( q{run_statuses} )->create( {
                run_status_dict    => $self->get_status_dict_row('RunStatusDict', $description),
                date               => $date,
                iscurrent          => $make_new_current,
                id_user            => $user_id,
        } );
    };
    my $new_row = $self->result_source->schema->txn_do( $transaction );

    if ( $make_new_current ) {
        try {
            $self->run_status_event( $user_id, $new_row->id_run_status() );
            $self->instrument->autochange_status_if_needed($description, $user_id);
            my $auto = $STATUS_CHANGE_AUTO{$description};
            if ($auto) {
                $new_row = $self->update_run_status($auto);
            }
        } catch {
            carp "Error performing post run status change actions \
                  (event, auto run and instrument status update): $_";
        }
    }

    return $new_row;
}

=head2 propagate_status_from_lanes

Checks whether the current status of the lanes should trigger the run
status update, triggers the update if appropriate. Returns true if
the trigger has been activated, false otherwise.

If correct behaviour with concurrent lane status updates is required,
this method should not be called within the transaction that updates
lane statuses since it needs visibility of current statuses of all
lanes of the run. 

=cut

sub propagate_status_from_lanes {
    my $self = shift;
   
    my $propagated = 0;
    my %statuses = ();
    foreach my $run_lane ($self->run_lanes()->all()) {
      my $current = $run_lane->current_run_lane_status;
      if (!$current) {
        return $propagated; # One of lanes does not have current status
      }
      $statuses{$current->description} = 1;
    }
    if (scalar(keys %statuses) == 1) {
        my ($description, $value)  = each %statuses;
        my $auto = $STATUS_PROPAGATE_AUTO{$description};
        if ( $auto ) {
            $self->update_run_status($auto);
            $propagated = 1;  
        }
    }

    return $propagated;
}

=head2 run_status_event

Log a status change to the event table. Require a user identifier (id/name)
the id of the run_status. Accept a date argument but default to NOW() if it's
not supplied. Return the row id.

=cut

sub run_status_event {
    my ( $self, $user_identifier, $run_status_id, $when ) = @_;

    # This will take care of croaking if $user_identifier is not supplied.
    my $user_id = $self->_user_rs->_insist_on_valid_row($user_identifier)->
                    id_user();

    croak 'No run_status id supplied' if !defined $run_status_id;

    my $id_event_type =
        $self->_event_type_rs->id_query( 'run_status', 'status change' );

    croak 'No matching event type found' if !defined $id_event_type;

    ( defined $when ) || ( $when = $self->get_time_now());


    my $insert = $self->result_source->schema->resultset('Event')->create(
        {
            id_event_type => $id_event_type,
            date          => $when,
            entity_id     => $run_status_id,
            id_user       => $user_id,
        }
    );

    return $insert->id_event();
}

=head2 _map_opposed_tags

Create a hashref that matches mutually exclusive run tags together.

=cut

sub _map_opposed_tags {
    my ($self) = @_;

    # Make some shorthand.
    my $shorter = sub { $self->_tag_rs->_insist_on_valid_row($_[0]); };

    my $paired_read_id = $shorter->('paired_read')->id_tag();
    my $single_read_id = $shorter->('single_read')->id_tag();
    my $paired_end_id  = $shorter->('paired_end')->id_tag();
    my $single_end_id  = $shorter->('single_end')->id_tag();
    my $good_id        = $shorter->('good')->id_tag();
    my $bad_id         = $shorter->('bad')->id_tag();
    my $slot_a_id      = $shorter->('fc_slotA')->id_tag();
    my $slot_b_id      = $shorter->('fc_slotB')->id_tag();

    $self->{opposite_tag} = {
        $paired_read_id => $single_read_id,
        $single_read_id => $paired_read_id,

        $paired_end_id  => $single_end_id,
        $single_end_id  => $paired_end_id,

        $good_id        => $bad_id,
        $bad_id         => $good_id,

        $slot_a_id      => $slot_b_id,
        $slot_b_id      => $slot_a_id,
    };

    return;
}

=head2 _set_mutually_exclusive_tags

Some tags are paired and mutually exclusive (paired_end/single_end,
paired_read/single_read, good/bad). This is method is called by set_tag to do
the heavy lifting of setting one tag and making sure the opposite tag is not
set.

=cut

sub _set_mutually_exclusive_tags {
    my ( $self, $user_identifier, $is_tag_id, $is_not_tag_id ) = @_;

    my $user_id =
        $self->_user_rs->_insist_on_valid_row($user_identifier)->id_user();

    my $tag_run_rs =
        $self->result_source->schema->resultset('TagRun')->search(
            {
                id_run => $self->id_run(),
                id_tag => { IN => [ $is_tag_id, $is_not_tag_id ] },
            }
    );


    my $already_set = 0;
    while ( my $row = $tag_run_rs->next() ) {
        if ( $row->id_tag() eq $is_not_tag_id ) {
            $row->delete();
            next;
        }

        if ( $row->id_tag() eq $is_tag_id ) {
            $already_set = 1;
        }
    }

    return if $already_set;

    $self->result_source->schema->resultset('TagRun')->create(
        {
            id_run  => $self->id_run(),
            id_tag  => $is_tag_id,
            id_user => $user_id,
            date    => $self->get_time_now(),
        }
    );


    return;
}

=head2 set_tag

General method for setting/creating TagRun rows.

=cut

sub set_tag {
    my ( $self, $user_identifier, $tag_identifier ) = @_;

    if ( !$tag_identifier ) {
        carp 'No tag supplied.';
        return;
    }

    my $user_id =
        $self->_user_rs->_insist_on_valid_row($user_identifier)->id_user();

    my $tag_id =
        $self->_tag_rs->_insist_on_valid_row($tag_identifier)->id_tag();

    ( scalar keys %{ $self->{opposite_tag} } ) || $self->_map_opposed_tags();

    if ( defined $self->{opposite_tag}{$tag_id} ) {
        $self->_set_mutually_exclusive_tags(
            $user_identifier, $tag_id, $self->{opposite_tag}{$tag_id},
        );
        return;
    }

    $self->result_source->schema->resultset('TagRun')->find_or_create(
        {
            id_run  => $self->id_run(),
            id_tag  => $tag_id,
            date    => $self->get_time_now(),
            id_user => $user_id,
        },
        { key => 'u_idrun_idtag' }
    );

    return;
}

=head2 unset_tag

General method for unsetting TagRun rows. It won't complain if the tag was
already unset on the run. Also note that unsetting a tag that has a mutually
exlusive opposite number DOES NOT set that opposite number (or unset it).

=cut

sub unset_tag {
    my ( $self, $user_identifier, $tag_identifier ) = @_;

    my $user_id =
        $self->_user_rs->_insist_on_valid_row($user_identifier)->id_user();

    my $tag_id =
        $self->_tag_rs->_insist_on_valid_row($tag_identifier)->id_tag();

#    ( scalar keys %{ $self->{opposite_tag} } ) || $self->_map_opposed_tags();

#    if ( defined $self->{opposite_tag}{$tag_id} ) {
#        $self->_set_mutually_exclusive_tags(
#            $user_identifier, $self->{opposite_tag}{$tag_id}, $tag_id,
#        );
#        return;
#    }

    my $record = 
        $self->result_source->schema->resultset('TagRun')->search(
            {
                id_run  => $self->id_run(),
                id_tag  => $tag_id,
            }
        );

    return $record->delete();
}

=head2 is_tag_set

Test whether a suppled tag (db id or text) is set for the run. Returns 0 if
not, and 1 if it is. Actually it returns the number of times it is set for the
run. This should only ever be 1, but the method doesn't complain or even check
if it's not.

=cut

sub is_tag_set {
    my ( $self, $tag_identifier ) = @_;

    my $tag_id =
        $self->_tag_rs->_insist_on_valid_row($tag_identifier)->id_tag();

    return 
        $self->result_source->schema->resultset('TagRun')->search(
            {
                id_run  => $self->id_run(),
                id_tag  => $tag_id,
            }
        )->count();
}

=head2 forward_read

Get RunRead corresponding to the forward read.

=cut

sub forward_read {
    my ($self) = @_;
    return $self->runs_read->find({read_order=>1});
}

=head2 reverse_read

Get RunRead corresponding to the reverse read.

=cut

sub reverse_read {
    my ($self) = @_;
    return $self->runs_read->find({read_order=>2+$self->is_tag_set(q(multiplex))});
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

Result class definition in DBIx binding for npg tracking database.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose

=item MooseX::NonMoose

=item MooseX::MarkAsMethods

=item DBIx::Class::Core

=item DBIx::Class::InflateColumn::DateTime

=item Carp

=item Try::Tiny

=item Readonly

=item npg_tracking::Schema::Retriever

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David Jackson E<lt>david.jackson@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Limited

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.

=cut
