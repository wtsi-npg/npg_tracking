use utf8;
package npg_tracking::Schema::Result::InstrumentDesignation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::InstrumentDesignation

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

=head1 TABLE: C<instrument_designation>

=cut

__PACKAGE__->table("instrument_designation");

=head1 ACCESSORS

=head2 id_instrument_designation

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_instrument

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 id_designation

  data_type: 'integer'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id_instrument_designation",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "id_instrument",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "id_designation",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_instrument_designation>

=back

=cut

__PACKAGE__->set_primary_key("id_instrument_designation");

=head1 RELATIONS

=head2 designation

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::Designation>

=cut

__PACKAGE__->belongs_to(
  "designation",
  "npg_tracking::Schema::Result::Designation",
  { id_designation => "id_designation" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 instrument

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::Instrument>

=cut

__PACKAGE__->belongs_to(
  "instrument",
  "npg_tracking::Schema::Result::Instrument",
  { id_instrument => "id_instrument" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2023-10-23 17:02:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KHcCuo5jZz2lAyNyo5Kqyg

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

__PACKAGE__->meta->make_immutable;
1;
