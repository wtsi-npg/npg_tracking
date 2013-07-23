use utf8;
package npg_tracking::Schema::Result::InstrumentStatusAnnotation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::InstrumentStatusAnnotation

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

=head1 TABLE: C<instrument_status_annotation>

=cut

__PACKAGE__->table("instrument_status_annotation");

=head1 ACCESSORS

=head2 id_instrument_status_annotation

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_instrument_status

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 id_annotation

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id_instrument_status_annotation",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "id_instrument_status",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "id_annotation",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_instrument_status_annotation>

=back

=cut

__PACKAGE__->set_primary_key("id_instrument_status_annotation");

=head1 UNIQUE CONSTRAINTS

=head2 C<id_instrument_status>

=over 4

=item * L</id_instrument_status>

=item * L</id_annotation>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "id_instrument_status",
  ["id_instrument_status", "id_annotation"],
);

=head1 RELATIONS

=head2 annotation

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::Annotation>

=cut

__PACKAGE__->belongs_to(
  "annotation",
  "npg_tracking::Schema::Result::Annotation",
  { id_annotation => "id_annotation" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 instrument_status

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::InstrumentStatus>

=cut

__PACKAGE__->belongs_to(
  "instrument_status",
  "npg_tracking::Schema::Result::InstrumentStatus",
  { id_instrument_status => "id_instrument_status" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1Nry/5/Z7srL49QFt5725A
# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: dj3 $
# Created:       2010-04-08
# Last Modified: $Date: 2010-11-08 15:02:27 +0000 (Mon, 08 Nov 2010) $
# Id:            $Id: InstrumentStatusAnnotation.pm 11663 2010-11-08 15:02:27Z dj3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema/Result/InstrumentStatusAnnotation.pm $

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 11663 $ =~ /(\d+)/mxs; $r; };

1;


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
