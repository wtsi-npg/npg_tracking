use utf8;
package npg_tracking::Schema::Result::Designation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::Designation

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

=head1 TABLE: C<designation>

=cut

__PACKAGE__->table("designation");

=head1 ACCESSORS

=head2 id_designation

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 description

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=cut

__PACKAGE__->add_columns(
  "id_designation",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 64 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_designation>

=back

=cut

__PACKAGE__->set_primary_key("id_designation");

=head1 RELATIONS

=head2 instrument_designations

Type: has_many

Related object: L<npg_tracking::Schema::Result::InstrumentDesignation>

=cut

__PACKAGE__->has_many(
  "instrument_designations",
  "npg_tracking::Schema::Result::InstrumentDesignation",
  { "foreign.id_designation" => "self.id_designation" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZE2wjA73jXTH5Bolucxx6g

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

=head2 instruments

Type: many_to_many

Related object: L<npg_tracking::Schema::Result::Instrument>

=cut

__PACKAGE__->many_to_many('instruments' => 'instrument_designations', 'instrument');

__PACKAGE__->meta->make_immutable;
1;
