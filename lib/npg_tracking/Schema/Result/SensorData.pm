package npg_tracking::Schema::Result::SensorData;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

npg_tracking::Schema::Result::SensorData

=cut

__PACKAGE__->table("sensor_data");

=head1 ACCESSORS

=head2 id_sensor_data

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 date

  data_type: 'timestamp'
  default_value: CURRENT_TIMESTAMP
  is_nullable: 0

=head2 id_sensor

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 value

  data_type: 'double precision'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id_sensor_data",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "date",
  {
    data_type     => "timestamp",
    default_value => \"CURRENT_TIMESTAMP",
    is_nullable   => 0,
  },
  "id_sensor",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "value",
  { data_type => "double precision", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id_sensor_data");

=head1 RELATIONS

=head2 sensor

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::Sensor>

=cut

__PACKAGE__->belongs_to(
  "sensor",
  "npg_tracking::Schema::Result::Sensor",
  { id_sensor => "id_sensor" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 sensor_data_instruments

Type: has_many

Related object: L<npg_tracking::Schema::Result::SensorDataInstrument>

=cut

__PACKAGE__->has_many(
  "sensor_data_instruments",
  "npg_tracking::Schema::Result::SensorDataInstrument",
  { "foreign.id_sensor_data" => "self.id_sensor_data" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.06001 @ 2012-03-08 17:04:11
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:yqYUcRdQdIk4w9YT3YrZBg
# You can replace this text with custom content, and it will be preserved on regeneration

=head2 insert
Override the insert function to emulate a database trigger

=cut

sub insert {
	my ($self, @args) = @_;

	# first insert the sensor_data record
	$self->next::method(@args);

	# Then emulate the database trigger to fill the sensor_data_instrument table
	my @rs = $self->sensor->sensor_instruments;
	foreach my $row (@rs) {
		$self->create_related('sensor_data_instruments',{ id_instrument=>$row->id_instrument});
	}
}

=head2 instruments
Type: many_to_many

Related object: L<npg_tracking::Schema::Result::Instrument>

=cut

__PACKAGE__->many_to_many('instruments' => 'sensor_data_instruments', 'instrument');


1;
