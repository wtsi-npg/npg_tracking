use utf8;
package npg_tracking::Schema::Result::RunLaneStatusDict;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::RunLaneStatusDict

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

=head1 TABLE: C<run_lane_status_dict>

=cut

__PACKAGE__->table("run_lane_status_dict");

=head1 ACCESSORS

=head2 id_run_lane_status_dict

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 description

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 64

=cut

__PACKAGE__->add_columns(
  "id_run_lane_status_dict",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "description",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 64 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_run_lane_status_dict>

=item * L</description>

=back

=cut

__PACKAGE__->set_primary_key("id_run_lane_status_dict", "description");

=head1 UNIQUE CONSTRAINTS

=head2 C<unique_rlstdict_description>

=over 4

=item * L</description>

=back

=cut

__PACKAGE__->add_unique_constraint("unique_rlstdict_description", ["description"]);

=head1 RELATIONS

=head2 run_lane_statuses

Type: has_many

Related object: L<npg_tracking::Schema::Result::RunLaneStatus>

=cut

__PACKAGE__->has_many(
  "run_lane_statuses",
  "npg_tracking::Schema::Result::RunLaneStatus",
  {
    "foreign.id_run_lane_status_dict" => "self.id_run_lane_status_dict",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2018-12-18 14:30:14
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:E6WgJgGO6lJccubTfi0tjg

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

__PACKAGE__->meta->make_immutable;

1;
