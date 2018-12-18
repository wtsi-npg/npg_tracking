use utf8;
package npg_tracking::Schema::Result::Tag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::Tag

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

=head1 TABLE: C<tag>

=cut

__PACKAGE__->table("tag");

=head1 ACCESSORS

=head2 id_tag

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 tag

  data_type: 'char'
  default_value: (empty string)
  is_nullable: 0
  size: 32

=cut

__PACKAGE__->add_columns(
  "id_tag",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "tag",
  { data_type => "char", default_value => "", is_nullable => 0, size => 32 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_tag>

=back

=cut

__PACKAGE__->set_primary_key("id_tag");

=head1 UNIQUE CONSTRAINTS

=head2 C<u_tag>

=over 4

=item * L</tag>

=back

=cut

__PACKAGE__->add_unique_constraint("u_tag", ["tag"]);

=head1 RELATIONS

=head2 tag_frequencies

Type: has_many

Related object: L<npg_tracking::Schema::Result::TagFrequency>

=cut

__PACKAGE__->has_many(
  "tag_frequencies",
  "npg_tracking::Schema::Result::TagFrequency",
  { "foreign.id_tag" => "self.id_tag" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tag_run_lanes

Type: has_many

Related object: L<npg_tracking::Schema::Result::TagRunLane>

=cut

__PACKAGE__->has_many(
  "tag_run_lanes",
  "npg_tracking::Schema::Result::TagRunLane",
  { "foreign.id_tag" => "self.id_tag" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tag_runs

Type: has_many

Related object: L<npg_tracking::Schema::Result::TagRun>

=cut

__PACKAGE__->has_many(
  "tag_runs",
  "npg_tracking::Schema::Result::TagRun",
  { "foreign.id_tag" => "self.id_tag" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:08gAge0C54WNuGJ3n4e29g

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';


=head2 runs

Type: many_to_many

Related object: L<npg_tracking::Schema::Result::Run>

=cut

__PACKAGE__->many_to_many('runs' => 'tag_runs', 'run');

__PACKAGE__->meta->make_immutable;
1;
