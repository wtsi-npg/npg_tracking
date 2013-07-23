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


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:YW44Rtc9qBN/G4r419nMIA
# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: mg8 $
# Created:       2010-04-08
# Last Modified: $Date: 2011-09-09 14:59:49 +0100 (Fri, 09 Sep 2011) $
# Id:            $Id: RunLaneStatusDict.pm 14155 2011-09-09 13:59:49Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema/Result/RunLaneStatusDict.pm $

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14155 $ =~ /(\d+)/mxs; $r; };

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
                     ? 'id_run_lane_status_dict'
                     : 'description' ;

    my $rs = $self->result_source->schema->resultset('RunLaneStatusDict')->
                search( { $field => lc $arg, } );

    return if $rs->count() < 1;

    croak 'Panic! Multiple run_lane_status_dict rows found' if $rs->count() > 1;

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
1;



# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
