use utf8;
package npg_tracking::Schema::Result::InstrumentStatusDict;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::InstrumentStatusDict

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

=head1 TABLE: C<instrument_status_dict>

=cut

__PACKAGE__->table("instrument_status_dict");

=head1 ACCESSORS

=head2 id_instrument_status_dict

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 description

  data_type: 'char'
  default_value: (empty string)
  is_nullable: 0
  size: 64

=head2 iscurrent

  data_type: 'tinyint'
  default_value: 1
  extra: {unsigned => 1}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id_instrument_status_dict",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "description",
  { data_type => "char", default_value => "", is_nullable => 0, size => 64 },
  "iscurrent",
  {
    data_type => "tinyint",
    default_value => 1,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_instrument_status_dict>

=back

=cut

__PACKAGE__->set_primary_key("id_instrument_status_dict");

=head1 UNIQUE CONSTRAINTS

=head2 C<unique_instrdict_description>

=over 4

=item * L</description>

=back

=cut

__PACKAGE__->add_unique_constraint("unique_instrdict_description", ["description"]);

=head1 RELATIONS

=head2 instrument_statuses

Type: has_many

Related object: L<npg_tracking::Schema::Result::InstrumentStatus>

=cut

__PACKAGE__->has_many(
  "instrument_statuses",
  "npg_tracking::Schema::Result::InstrumentStatus",
  {
    "foreign.id_instrument_status_dict" => "self.id_instrument_status_dict",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2018-12-18 14:30:14
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jhd+l0+Y1Wd/UWRCsPHFbg

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

__PACKAGE__->meta->make_immutable;

1;
