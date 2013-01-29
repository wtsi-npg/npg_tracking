package npg_tracking::Schema::Result::RunLane;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

npg_tracking::Schema::Result::RunLane

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
__PACKAGE__->set_primary_key("id_run_lane");
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
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
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


# Created by DBIx::Class::Schema::Loader v0.06001 @ 2012-03-06 12:27:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BswJ7kdOGO8FqRfZOXGuZg
# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: js10 $
# Created:       2010-04-08
# Last Modified: $Date: 2012-03-20 12:02:08 +0000 (Tue, 20 Mar 2012) $
# Id:            $Id: RunLane.pm 15357 2012-03-20 12:02:08Z js10 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema/Result/RunLane.pm $

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 15357 $ =~ /(\d+)/mxs; $r; };

=head2 current_run_lane_status

Returns the current_run_lane_status dbix object

=cut

sub current_run_lane_status {
  my ( $self ) = @_;
  return $self->run_lane_statuses()->search({iscurrent => 1})->first(); #not nice - would like this defined by a relationship
}

1;

