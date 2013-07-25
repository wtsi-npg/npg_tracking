use utf8;
package npg_tracking::Schema::Result::ManualQcStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::ManualQcStatus

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

=head1 TABLE: C<manual_qc_status>

=cut

__PACKAGE__->table("manual_qc_status");

=head1 ACCESSORS

=head2 id_manual_qc_status

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 iscurrent

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 id_user

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 status

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 lims_object_id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 0

=head2 lims_object_type

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 batch_id

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 position

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 referer

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "id_manual_qc_status",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
  "iscurrent",
  { data_type => "tinyint", extra => { unsigned => 1 }, is_nullable => 0 },
  "id_user",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "status",
  { data_type => "tinyint", extra => { unsigned => 1 }, is_nullable => 0 },
  "lims_object_id",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 0 },
  "lims_object_type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "batch_id",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
  "position",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "referer",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_manual_qc_status>

=back

=cut

__PACKAGE__->set_primary_key("id_manual_qc_status");

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


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Gq4d3X/lqF6rgR5xVNtOUQ
# Author:        marina.gourtovaia@sanger.ac.uk
# Maintainer:    $Author: jo3 $
# Created:       2010-10-27
# Last Modified: $Date: 2010-10-26 15:10:45 +0100 (Tue, 26 Oct 2010) $
# Id:            $Id: Run.pm 11485 2010-10-26 14:10:45Z jo3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/branches/prerelease-52.0/lib/npg_tracking/Schema/Result/Run.pm $

1;


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
