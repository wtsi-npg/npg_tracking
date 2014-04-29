use utf8;
package npg_tracking::Schema::Result::User2usergroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::User2usergroup

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

=head1 TABLE: C<user2usergroup>

=cut

__PACKAGE__->table("user2usergroup");

=head1 ACCESSORS

=head2 id_user_usergroup

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_user

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 id_usergroup

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 level

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id_user_usergroup",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "id_user",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "id_usergroup",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "level",
  { data_type => "tinyint", extra => { unsigned => 1 }, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_user_usergroup>

=back

=cut

__PACKAGE__->set_primary_key("id_user_usergroup");

=head1 RELATIONS

=head2 user

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "npg_tracking::Schema::Result::User",
  { id_user => "id_user" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 usergroup

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::Usergroup>

=cut

__PACKAGE__->belongs_to(
  "usergroup",
  "npg_tracking::Schema::Result::Usergroup",
  { id_usergroup => "id_usergroup" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2014-02-20 10:43:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rDM3WmEbGffIzjPO9maIeA

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

__PACKAGE__->meta->make_immutable;
1;
