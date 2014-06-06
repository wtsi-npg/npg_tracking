use utf8;
package npg_tracking::Schema::Result::Usergroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::Usergroup

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

=head1 TABLE: C<usergroup>

=cut

__PACKAGE__->table("usergroup");

=head1 ACCESSORS

=head2 groupname

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 32

=head2 id_usergroup

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 is_public

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 description

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 1
  size: 128

=cut

__PACKAGE__->add_columns(
  "groupname",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 32 },
  "id_usergroup",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "is_public",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "description",
  { data_type => "varchar", default_value => "", is_nullable => 1, size => 128 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_usergroup>

=back

=cut

__PACKAGE__->set_primary_key("id_usergroup");

=head1 RELATIONS

=head2 event_type_subscribers

Type: has_many

Related object: L<npg_tracking::Schema::Result::EventTypeSubscriber>

=cut

__PACKAGE__->has_many(
  "event_type_subscribers",
  "npg_tracking::Schema::Result::EventTypeSubscriber",
  { "foreign.id_usergroup" => "self.id_usergroup" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user2usergroups

Type: has_many

Related object: L<npg_tracking::Schema::Result::User2usergroup>

=cut

__PACKAGE__->has_many(
  "user2usergroups",
  "npg_tracking::Schema::Result::User2usergroup",
  { "foreign.id_usergroup" => "self.id_usergroup" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fWkhaUn/pPyRoLyYXBI80w

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

=head2 users

Type: many_to_many

Related object: L<npg_tracking::Schema::Result::User>

=cut

__PACKAGE__->many_to_many(
  'users' => 'user2usergroups', 'user'
);

__PACKAGE__->meta->make_immutable;
1;
