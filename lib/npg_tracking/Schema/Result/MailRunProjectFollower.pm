use utf8;
package npg_tracking::Schema::Result::MailRunProjectFollower;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::MailRunProjectFollower

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

=head1 TABLE: C<mail_run_project_followers>

=cut

__PACKAGE__->table("mail_run_project_followers");

=head1 ACCESSORS

=head2 id_mail_run_project_followers

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 run_complete_sent

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 run_archived_sent

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 id_run

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id_mail_run_project_followers",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "run_complete_sent",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "run_archived_sent",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "id_run",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_mail_run_project_followers>

=back

=cut

__PACKAGE__->set_primary_key("id_mail_run_project_followers");

=head1 UNIQUE CONSTRAINTS

=head2 C<run_index>

=over 4

=item * L</id_run>

=back

=cut

__PACKAGE__->add_unique_constraint("run_index", ["id_run"]);

=head1 RELATIONS

=head2 run

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::Run>

=cut

__PACKAGE__->belongs_to(
  "run",
  "npg_tracking::Schema::Result::Run",
  { id_run => "id_run" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Y2Nk+KBZBnLGOQ+EOS4jSw

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

__PACKAGE__->meta->make_immutable;
1;
