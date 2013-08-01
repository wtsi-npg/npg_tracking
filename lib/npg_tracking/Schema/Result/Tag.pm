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
# Maintainer:    $Author: gq1 $
# Created:       2010-04-08
# Last Modified: $Date: 2012-01-03 15:55:58 +0000 (Tue, 03 Jan 2012) $
# Id:            $Id: Tag.pm 14844 2012-01-03 15:55:58Z gq1 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema/Result/Tag.pm $

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14844 $ =~ /(\d+)/mxs; $r; };

use Carp;

=head2 check_row_validity

Take a single argument and see if it corresponds to a valid row in the tag
table. The argument can be the primary key, or the tag text. The argument
is converted to lower case before checking.

The method croaks if no argument is supplied, if no row is found (or if
multiple rows are matched) otherwise the row is returned as a DBIx::Class::Row
object.

=cut

sub check_row_validity {
    my ( $self, $arg ) = @_;

    croak 'Argument required' if !defined $arg;

    my $field = ( $arg =~ m/^ \d+ $/msx )
                     ? 'id_tag'
                     : 'tag' ;

    my $rs = $self->result_source->schema->resultset('Tag')->
        search( { $field => $arg, } );

    return if $rs->count() < 1;
    croak 'Panic! Multiple tag rows found' if $rs->count() > 1;

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

=head2 runs

Type: many_to_many

Related object: L<npg_tracking::Schema::Result::Run>

=cut

__PACKAGE__->many_to_many('runs' => 'tag_runs', 'run');


1;



# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
