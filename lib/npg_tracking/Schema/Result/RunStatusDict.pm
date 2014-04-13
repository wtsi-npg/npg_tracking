use utf8;
package npg_tracking::Schema::Result::RunStatusDict;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::RunStatusDict

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

=head1 TABLE: C<run_status_dict>

=cut

__PACKAGE__->table("run_status_dict");

=head1 ACCESSORS

=head2 id_run_status_dict

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 description

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 64

=head2 iscurrent

  data_type: 'tinyint'
  default_value: 1
  extra: {unsigned => 1}
  is_nullable: 0

=head2 temporal_index

  data_type: 'smallint'
  extra: {unsigned => 1}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id_run_status_dict",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "description",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 64 },
  "iscurrent",
  {
    data_type => "tinyint",
    default_value => 1,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "temporal_index",
  { data_type => "smallint", extra => { unsigned => 1 }, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_run_status_dict>

=back

=cut

__PACKAGE__->set_primary_key("id_run_status_dict");

=head1 RELATIONS

=head2 run_statuses

Type: has_many

Related object: L<npg_tracking::Schema::Result::RunStatus>

=cut

__PACKAGE__->has_many(
  "run_statuses",
  "npg_tracking::Schema::Result::RunStatus",
  { "foreign.id_run_status_dict" => "self.id_run_status_dict" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1GEPxFttJzowYc2uzN9Y5g

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

use Carp;

=head2 check_row_validity

Take a single argument and see if it corresponds to a valid row in the
run_status_dictionary table. The argument can be the primary key, or the
description field. The argument is converted to lower case before checking.

The method croaks if no argument is supplied, if no row is found (or if,
multiple rows are matched) otherwise the row is returned as a DBIx::Class::Row
object.

=cut

sub check_row_validity {
    my ( $self, $arg ) = @_;

    croak 'Argument required' if !defined $arg;

    my $field = ( $arg =~ m/^ \d+ $/msx )
                     ? 'id_run_status_dict'
                     : 'description' ;

    my $rs = $self->result_source->schema->resultset('RunStatusDict')->
                search( { $field => lc $arg, } );

    return if $rs->count() < 1;

    croak 'Panic! Multiple run_status_dict rows found' if $rs->count() > 1;

    my $row = $rs->first();
    if (!$row->iscurrent) {
        croak 'Run status "' . $row->description . '" is not current';
    }
    return $row;
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

__PACKAGE__->meta->make_immutable;
1;
