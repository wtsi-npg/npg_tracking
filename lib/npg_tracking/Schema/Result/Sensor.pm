use utf8;
package npg_tracking::Schema::Result::Sensor;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::Sensor

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

=head1 TABLE: C<sensor>

=cut

__PACKAGE__->table("sensor");

=head1 ACCESSORS

=head2 id_sensor

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 is_current

  data_type: 'tinyint'
  is_nullable: 0

=head2 guid

  data_type: 'varchar'
  is_nullable: 0
  size: 50

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=head2 description

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=cut

__PACKAGE__->add_columns(
  "id_sensor",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "is_current",
  { data_type => "tinyint", is_nullable => 0 },
  "guid",
  { data_type => "varchar", is_nullable => 0, size => 50 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "description",
  { data_type => "varchar", is_nullable => 1, size => 50 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_sensor>

=back

=cut

__PACKAGE__->set_primary_key("id_sensor");

=head1 UNIQUE CONSTRAINTS

=head2 C<guid>

=over 4

=item * L</guid>

=back

=cut

__PACKAGE__->add_unique_constraint("guid", ["guid"]);

=head2 C<name>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name", ["name"]);

=head1 RELATIONS

=head2 sensor_datas

Type: has_many

Related object: L<npg_tracking::Schema::Result::SensorData>

=cut

__PACKAGE__->has_many(
  "sensor_datas",
  "npg_tracking::Schema::Result::SensorData",
  { "foreign.id_sensor" => "self.id_sensor" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 sensor_instruments

Type: has_many

Related object: L<npg_tracking::Schema::Result::SensorInstrument>

=cut

__PACKAGE__->has_many(
  "sensor_instruments",
  "npg_tracking::Schema::Result::SensorInstrument",
  { "foreign.id_sensor" => "self.id_sensor" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hZh6YatT+bkL7jTj6I2qZQ

our $VERSION = '0';

=head2 instruments

Type: many_to_many

Related object: L<npg_tracking::Schema::Result::Instrument>

=cut

__PACKAGE__->many_to_many('instruments' => 'sensor_instruments', 'instrument');

__PACKAGE__->meta->make_immutable;
1;
