use utf8;
package npg_tracking::Schema::Result::InstrumentFormat;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::InstrumentFormat

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

=head1 TABLE: C<instrument_format>

=cut

__PACKAGE__->table("instrument_format");

=head1 ACCESSORS

=head2 id_instrument_format

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_manufacturer

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 model

  data_type: 'char'
  is_nullable: 1
  size: 64

=head2 iscurrent

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 default_tiles

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 default_columns

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 days_between_washes

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 runs_between_washes

  data_type: 'integer'
  extra: {unsigned => 1}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id_instrument_format",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "id_manufacturer",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "model",
  { data_type => "char", is_nullable => 1, size => 64 },
  "iscurrent",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "default_tiles",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "default_columns",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "days_between_washes",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
  "runs_between_washes",
  { data_type => "integer", extra => { unsigned => 1 }, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_instrument_format>

=back

=cut

__PACKAGE__->set_primary_key("id_instrument_format");

=head1 RELATIONS

=head2 instruments

Type: has_many

Related object: L<npg_tracking::Schema::Result::Instrument>

=cut

__PACKAGE__->has_many(
  "instruments",
  "npg_tracking::Schema::Result::Instrument",
  { "foreign.id_instrument_format" => "self.id_instrument_format" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 manufacturer

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::Manufacturer>

=cut

__PACKAGE__->belongs_to(
  "manufacturer",
  "npg_tracking::Schema::Result::Manufacturer",
  { id_manufacturer => "id_manufacturer" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 runs

Type: has_many

Related object: L<npg_tracking::Schema::Result::Run>

=cut

__PACKAGE__->has_many(
  "runs",
  "npg_tracking::Schema::Result::Run",
  { "foreign.id_instrument_format" => "self.id_instrument_format" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07052 @ 2024-04-09 10:35:17
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:elkjaVkCGUOAo8WzkpdV/A

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

__PACKAGE__->meta->make_immutable;
1;
