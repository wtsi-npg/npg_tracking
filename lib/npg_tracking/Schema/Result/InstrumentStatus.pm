use utf8;
package npg_tracking::Schema::Result::InstrumentStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::InstrumentStatus

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

=head1 TABLE: C<instrument_status>

=cut

__PACKAGE__->table("instrument_status");

=head1 ACCESSORS

=head2 id_instrument_status

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_instrument

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 id_instrument_status_dict

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  default_value: '0000-00-00 00:00:00'
  is_nullable: 0

=head2 id_user

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 comment

  data_type: 'text'
  is_nullable: 1

=head2 iscurrent

  data_type: 'tinyint'
  default_value: 0
  extra: {unsigned => 1}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id_instrument_status",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "id_instrument",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "id_instrument_status_dict",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    default_value => "0000-00-00 00:00:00",
    is_nullable => 0,
  },
  "id_user",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "comment",
  { data_type => "text", is_nullable => 1 },
  "iscurrent",
  {
    data_type => "tinyint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_instrument_status>

=back

=cut

__PACKAGE__->set_primary_key("id_instrument_status");

=head1 RELATIONS

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

=head2 instrument_status_annotations

Type: has_many

Related object: L<npg_tracking::Schema::Result::InstrumentStatusAnnotation>

=cut

__PACKAGE__->has_many(
  "instrument_status_annotations",
  "npg_tracking::Schema::Result::InstrumentStatusAnnotation",
  { "foreign.id_instrument_status" => "self.id_instrument_status" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 instrument_status_dict

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::InstrumentStatusDict>

=cut

__PACKAGE__->belongs_to(
  "instrument_status_dict",
  "npg_tracking::Schema::Result::InstrumentStatusDict",
  { id_instrument_status_dict => "id_instrument_status_dict" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 user

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "npg_tracking::Schema::Result::User",
  { id_user => "id_user" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2023-10-23 17:02:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:esGkAihro4/eSQRnoK9hfw

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

=head2 summary

Short status summary.

=cut

sub summary {
  my $self = shift;
  return sprintf 'Instrument %s status changed to "%s"',
    $self->instrument()->name(),
    $self->instrument_status_dict()->description();
}

=head2 information

Information obout this status.

=cut

sub information {
  my $self = shift;
  my $info = sprintf q[%s on %s by %s],
    $self->summary(),
    $self->date()->strftime('%F %T'),
    $self->user()->username();
  if ($self->comment()) {
    $info .= '. Comment: ' . $self->comment();
  }
  return $info;
}

__PACKAGE__->meta->make_immutable;
1;
