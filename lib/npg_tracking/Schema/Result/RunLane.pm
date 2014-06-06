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

our $VERSION = '0';

=head2 current_run_lane_status

Returns the current_run_lane_status dbix object

=cut

sub current_run_lane_status {
  my ( $self ) = @_;
  return $self->run_lane_statuses()->search({iscurrent => 1})->first(); #not nice - would like this defined by a relationship
}

__PACKAGE__->meta->make_immutable;
1;
