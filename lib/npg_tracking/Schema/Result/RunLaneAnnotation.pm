use utf8;
package npg_tracking::Schema::Result::RunLaneAnnotation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::RunLaneAnnotation

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

=head1 TABLE: C<run_lane_annotation>

=cut

__PACKAGE__->table("run_lane_annotation");

=head1 ACCESSORS

=head2 id_run_lane_annotation

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_run_lane

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
  "id_run_lane_annotation",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "id_run_lane",
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

=item * L</id_run_lane_annotation>

=back

=cut

__PACKAGE__->set_primary_key("id_run_lane_annotation");

=head1 RELATIONS

=head2 annotation

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::Annotation>

=cut

__PACKAGE__->belongs_to(
  "annotation",
  "npg_tracking::Schema::Result::Annotation",
  { id_annotation => "id_annotation" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 run_lane

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::RunLane>

=cut

__PACKAGE__->belongs_to(
  "run_lane",
  "npg_tracking::Schema::Result::RunLane",
  { id_run_lane => "id_run_lane" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2023-10-23 17:02:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zSY29s221/qV7AsJvmk7HQ

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

=head2 id_run

Run id this annotation relates to.

=cut

sub id_run {
  my $self = shift;
  return $self->run_lane()->id_run();
}

=head2 position

Position (lane number) this annotation relates to.

=cut

sub position {
  my $self = shift;
  return $self->run_lane()->position();
}

=head2 summary

Short annotation summary.

=cut

sub summary {
  my $self = shift;
  return sprintf 'Run %i lane %i annotated by %s',
    $self->id_run(),
    $self->position(),
    $self->annotation()->username();
}

=head2 information

Full annotation description.

=cut

sub information {
  my $self = shift;
  return sprintf '%s on %s - %s',
    $self->summary(),
    $self->annotation()->date_as_string(),
    $self->annotation()->comment();
}

__PACKAGE__->meta->make_immutable;
1;
