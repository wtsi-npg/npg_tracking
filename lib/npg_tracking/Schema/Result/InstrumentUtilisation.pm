use utf8;
package npg_tracking::Schema::Result::InstrumentUtilisation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::InstrumentUtilisation

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

=head1 TABLE: C<instrument_utilisation>

=cut

__PACKAGE__->table("instrument_utilisation");

=head1 ACCESSORS

=head2 id_instrument_utilisation

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 date

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 0

=head2 total_insts

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 perc_utilisation_total_insts

  data_type: 'float'
  default_value: 0.00
  extra: {unsigned => 1}
  is_nullable: 0
  size: [5,2]

=head2 perc_uptime_total_insts

  data_type: 'float'
  default_value: 0.00
  extra: {unsigned => 1}
  is_nullable: 0
  size: [5,2]

=head2 official_insts

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 perc_utilisation_official_insts

  data_type: 'float'
  default_value: 0.00
  extra: {unsigned => 1}
  is_nullable: 0
  size: [5,2]

=head2 perc_uptime_official_insts

  data_type: 'float'
  default_value: 0.00
  extra: {unsigned => 1}
  is_nullable: 0
  size: [5,2]

=head2 prod_insts

  data_type: 'integer'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=head2 perc_utilisation_prod_insts

  data_type: 'float'
  default_value: 0.00
  extra: {unsigned => 1}
  is_nullable: 0
  size: [5,2]

=head2 perc_uptime_prod_insts

  data_type: 'float'
  default_value: 0.00
  extra: {unsigned => 1}
  is_nullable: 0
  size: [5,2]

=head2 id_instrument_format

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id_instrument_utilisation",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "date",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 0 },
  "total_insts",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "perc_utilisation_total_insts",
  {
    data_type => "float",
    default_value => "0.00",
    extra => { unsigned => 1 },
    is_nullable => 0,
    size => [5, 2],
  },
  "perc_uptime_total_insts",
  {
    data_type => "float",
    default_value => "0.00",
    extra => { unsigned => 1 },
    is_nullable => 0,
    size => [5, 2],
  },
  "official_insts",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "perc_utilisation_official_insts",
  {
    data_type => "float",
    default_value => "0.00",
    extra => { unsigned => 1 },
    is_nullable => 0,
    size => [5, 2],
  },
  "perc_uptime_official_insts",
  {
    data_type => "float",
    default_value => "0.00",
    extra => { unsigned => 1 },
    is_nullable => 0,
    size => [5, 2],
  },
  "prod_insts",
  {
    data_type => "integer",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "perc_utilisation_prod_insts",
  {
    data_type => "float",
    default_value => "0.00",
    extra => { unsigned => 1 },
    is_nullable => 0,
    size => [5, 2],
  },
  "perc_uptime_prod_insts",
  {
    data_type => "float",
    default_value => "0.00",
    extra => { unsigned => 1 },
    is_nullable => 0,
    size => [5, 2],
  },
  "id_instrument_format",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_instrument_utilisation>

=back

=cut

__PACKAGE__->set_primary_key("id_instrument_utilisation");

=head1 UNIQUE CONSTRAINTS

=head2 C<uidx_date_format>

=over 4

=item * L</date>

=item * L</id_instrument_format>

=back

=cut

__PACKAGE__->add_unique_constraint("uidx_date_format", ["date", "id_instrument_format"]);

=head1 RELATIONS

=head2 instrument_format

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::InstrumentFormat>

=cut

__PACKAGE__->belongs_to(
  "instrument_format",
  "npg_tracking::Schema::Result::InstrumentFormat",
  { id_instrument_format => "id_instrument_format" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:XRcRHyyuFbfg8mml8Zazow

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

__PACKAGE__->meta->make_immutable;
1;
