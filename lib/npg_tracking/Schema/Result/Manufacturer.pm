use utf8;
package npg_tracking::Schema::Result::Manufacturer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::Manufacturer

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

=head1 TABLE: C<manufacturer>

=cut

__PACKAGE__->table("manufacturer");

=head1 ACCESSORS

=head2 id_manufacturer

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'char'
  is_nullable: 1
  size: 128

=cut

__PACKAGE__->add_columns(
  "id_manufacturer",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "name",
  { data_type => "char", is_nullable => 1, size => 128 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_manufacturer>

=back

=cut

__PACKAGE__->set_primary_key("id_manufacturer");

=head1 UNIQUE CONSTRAINTS

=head2 C<name>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name", ["name"]);

=head1 RELATIONS

=head2 instrument_formats

Type: has_many

Related object: L<npg_tracking::Schema::Result::InstrumentFormat>

=cut

__PACKAGE__->has_many(
  "instrument_formats",
  "npg_tracking::Schema::Result::InstrumentFormat",
  { "foreign.id_manufacturer" => "self.id_manufacturer" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Nmn0ylTc07tLn8zuJykqng

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

__PACKAGE__->meta->make_immutable;
1;
