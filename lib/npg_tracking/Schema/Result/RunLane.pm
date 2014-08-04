use utf8;
package npg_tracking::Schema::Result::RunLane;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::RunLane

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

=head1 TABLE: C<run_lane>

=cut

__PACKAGE__->table("run_lane");

=head1 ACCESSORS

=head2 id_run_lane

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_run

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 tile_count

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 tracks

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

Double=2

=head2 position

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 1

=head2 good_bad

  data_type: 'tinyint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id_run_lane",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "id_run",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "tile_count",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "tracks",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "position",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 1,
  },
  "good_bad",
  { data_type => "tinyint", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_run_lane>

=back

=cut

__PACKAGE__->set_primary_key("id_run_lane");

=head1 UNIQUE CONSTRAINTS

=head2 C<uq_id_run_position>

=over 4

=item * L</id_run>

=item * L</position>

=back

=cut

__PACKAGE__->add_unique_constraint("uq_id_run_position", ["id_run", "position"]);

=head1 RELATIONS

=head2 run

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::Run>

=cut

__PACKAGE__->belongs_to(
  "run",
  "npg_tracking::Schema::Result::Run",
  { id_run => "id_run" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 run_lane_annotations

Type: has_many

Related object: L<npg_tracking::Schema::Result::RunLaneAnnotation>

=cut

__PACKAGE__->has_many(
  "run_lane_annotations",
  "npg_tracking::Schema::Result::RunLaneAnnotation",
  { "foreign.id_run_lane" => "self.id_run_lane" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 run_lane_statuses

Type: has_many

Related object: L<npg_tracking::Schema::Result::RunLaneStatus>

=cut

__PACKAGE__->has_many(
  "run_lane_statuses",
  "npg_tracking::Schema::Result::RunLaneStatus",
  { "foreign.id_run_lane" => "self.id_run_lane" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tag_run_lanes

Type: has_many

Related object: L<npg_tracking::Schema::Result::TagRunLane>

=cut

__PACKAGE__->has_many(
  "tag_run_lanes",
  "npg_tracking::Schema::Result::TagRunLane",
  { "foreign.id_run_lane" => "self.id_run_lane" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:a/2jj/wekHtvD7+mU4hh5g

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

use Carp;
with qw/
        npg_tracking::Schema::Retriever
        npg_tracking::Schema::Time
       /;

our $VERSION = '0';

=head2 current_run_lane_status

Returns the current_run_lane_status dbix object

=cut

sub current_run_lane_status {
  my ( $self ) = @_;
  return $self->run_lane_statuses()->search({iscurrent => 1})->first(); #not nice - would like this defined by a relationship
}

=head2 update_status

Logs the status and, if appropriate, marks this status current for the lane.
Status description must be provided.

  $obj->update_status($description, $username, $date);

For some statuses, can trigger an update of run status.

=cut

sub update_status {
  my ( $self, $description, $username, $date ) = @_;

  $date ||=  $self->get_time_now();
  if ( ref $date ne 'DateTime' ) {
    croak '"time" argument should be a DateTime object';
  }

  my $use_pipeline_user = 1;
  my $id_user  = $self->get_user_id($username, $use_pipeline_user);
  my $desc_row = $self->get_status_dict_row('RunLaneStatusDict', $description);

  my $update_transaction = sub {

    my $lane_statuses =  $self->related_resultset( q{run_lane_statuses} );

    my $make_new_current = 1;
    my $current = $lane_statuses->search(
           {iscurrent => 1},
           {order_by  =>  { -desc => 'date'},},)->next; # get latest
    if ( $current ) {
      if ( $current->run_lane_status_dict->description eq $description) {
        return; # This status is already current
      }
      # If current status is later that the new one, do not make the new one current
      if ( $self->get_difference_seconds($current->date,$date) > 0 ) {
        $make_new_current = 0;
      }
    }

    if ( $current && $make_new_current ) {
      $lane_statuses->update_all( {iscurrent => 0} );
    }

    my $new_row = $self->related_resultset( q{run_lane_statuses} )->create( {
          run_lane_status_dict => $desc_row,
          date                 => $date,
          iscurrent            => $make_new_current,
          id_user              => $id_user,
    } );

    if ($make_new_current) {
      $self->run->propagate_status_from_lanes();
    }

    return $new_row;
  };
  
  return $self->result_source->schema->txn_do( $update_transaction );
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

=item npg_tracking::Schema::Retriever

=item npg_tracking::Schema::Time

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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

