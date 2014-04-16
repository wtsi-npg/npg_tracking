use utf8;
package npg_tracking::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::User

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

=head1 TABLE: C<user>

=cut

__PACKAGE__->table("user");

=head1 ACCESSORS

=head2 id_user

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 username

  data_type: 'char'
  is_nullable: 1
  size: 128

=head2 rfid

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=cut

__PACKAGE__->add_columns(
  "id_user",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "username",
  { data_type => "char", is_nullable => 1, size => 128 },
  "rfid",
  { data_type => "varchar", is_nullable => 1, size => 64 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_user>

=back

=cut

__PACKAGE__->set_primary_key("id_user");

=head1 UNIQUE CONSTRAINTS

=head2 C<rf_id>

=over 4

=item * L</rfid>

=back

=cut

__PACKAGE__->add_unique_constraint("rf_id", ["rfid"]);

=head2 C<uidx_username>

=over 4

=item * L</username>

=back

=cut

__PACKAGE__->add_unique_constraint("uidx_username", ["username"]);

=head1 RELATIONS

=head2 annotations

Type: has_many

Related object: L<npg_tracking::Schema::Result::Annotation>

=cut

__PACKAGE__->has_many(
  "annotations",
  "npg_tracking::Schema::Result::Annotation",
  { "foreign.id_user" => "self.id_user" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 events

Type: has_many

Related object: L<npg_tracking::Schema::Result::Event>

=cut

__PACKAGE__->has_many(
  "events",
  "npg_tracking::Schema::Result::Event",
  { "foreign.id_user" => "self.id_user" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 instrument_mods

Type: has_many

Related object: L<npg_tracking::Schema::Result::InstrumentMod>

=cut

__PACKAGE__->has_many(
  "instrument_mods",
  "npg_tracking::Schema::Result::InstrumentMod",
  { "foreign.id_user" => "self.id_user" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 instrument_statuses

Type: has_many

Related object: L<npg_tracking::Schema::Result::InstrumentStatus>

=cut

__PACKAGE__->has_many(
  "instrument_statuses",
  "npg_tracking::Schema::Result::InstrumentStatus",
  { "foreign.id_user" => "self.id_user" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 manual_qc_statuses

Type: has_many

Related object: L<npg_tracking::Schema::Result::ManualQcStatus>

=cut

__PACKAGE__->has_many(
  "manual_qc_statuses",
  "npg_tracking::Schema::Result::ManualQcStatus",
  { "foreign.id_user" => "self.id_user" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 run_lane_statuses

Type: has_many

Related object: L<npg_tracking::Schema::Result::RunLaneStatus>

=cut

__PACKAGE__->has_many(
  "run_lane_statuses",
  "npg_tracking::Schema::Result::RunLaneStatus",
  { "foreign.id_user" => "self.id_user" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 run_statuses

Type: has_many

Related object: L<npg_tracking::Schema::Result::RunStatus>

=cut

__PACKAGE__->has_many(
  "run_statuses",
  "npg_tracking::Schema::Result::RunStatus",
  { "foreign.id_user" => "self.id_user" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tag_run_lanes

Type: has_many

Related object: L<npg_tracking::Schema::Result::TagRunLane>

=cut

__PACKAGE__->has_many(
  "tag_run_lanes",
  "npg_tracking::Schema::Result::TagRunLane",
  { "foreign.id_user" => "self.id_user" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 tag_runs

Type: has_many

Related object: L<npg_tracking::Schema::Result::TagRun>

=cut

__PACKAGE__->has_many(
  "tag_runs",
  "npg_tracking::Schema::Result::TagRun",
  { "foreign.id_user" => "self.id_user" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user2usergroups

Type: has_many

Related object: L<npg_tracking::Schema::Result::User2usergroup>

=cut

__PACKAGE__->has_many(
  "user2usergroups",
  "npg_tracking::Schema::Result::User2usergroup",
  { "foreign.id_user" => "self.id_user" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dNtuo6HajBsOL+Z00k9RlA

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

=head2 usergroups

Type: many_to_many

Related object: L<npg_tracking::Schema::Result::Usergroup>

=cut

__PACKAGE__->many_to_many('usergroups' => 'user2usergroups', 'usergroup');
__PACKAGE__->add_unique_constraint('username', ['username']);


use Carp;

=head2 check_row_validity

Take a single argument and see if it corresponds to a valid row in the user
table. The argument can be the primary key, or the username. The argument
is converted to lower case before checking.

The method croaks if no argument is supplied or if multiple rows are matched
(this would indicate serious database problems). It returns undef if no match
at all is found, otherwise the row is returned as a DBIx::Class::Row object.

=cut

sub check_row_validity {
    my ( $self, $arg ) = @_;

    croak 'Argument required' if !defined $arg;

    my $field = ( $arg =~ m/^ \d+ $/msx )
                     ? 'id_user'
                     : 'username' ;

    my $rs = $self->result_source->schema->resultset('User')->
        search( { $field => lc $arg, } );

    return if $rs->count() < 1;
    croak 'Panic! Multiple user rows found' if $rs->count() > 1;

    return $rs->first();
}

=head2 _insist_on_valid_row

The above method is a general query tool. The user shouldn't have to deal with
a croak just because they asked about a row that doesn't exist.

This method is more severe and will croak in such a case. It is intended for
internal methods in other classes in this library so that they don't each have
to define their own user_validity check, but also can insist on a valid
identifier before proceeding.

It calls the above method, passing back the row object if the identifier is
valid, but croaking if check_row_validity returns undef. If check_row_validity
croaks (no argument, multiple rows returned) that suits this method's purpose.

Could we consider caching here? To reduce the number of database queries? User
identifiers are not likely to be created or changed during an object's
lifetime.

=cut

sub _insist_on_valid_row {
    my ( $self, $arg ) = @_;

    my $row_object = $self->check_row_validity($arg);

    croak "Invalid identifier: $arg" if !defined $row_object;

    return $row_object;
}


=head2 pipeline_id

Convenience method to return the database id field of the username 'pipeline'.

=cut

sub pipeline_id {
    my ($self) = @_;
    return $self->result_source->schema->resultset('User')->
                find( { username => 'pipeline' } )->id_user();
}

__PACKAGE__->meta->make_immutable;
1;
