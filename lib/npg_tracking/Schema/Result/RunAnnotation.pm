use utf8;
package npg_tracking::Schema::Result::RunAnnotation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::RunAnnotation

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

=head1 TABLE: C<run_annotation>

=cut

__PACKAGE__->table("run_annotation");

=head1 ACCESSORS

=head2 id_run_annotation

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_run

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 id_annotation

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 run_current_ok

  data_type: 'tinyint'
  extra: {unsigned => 1}
  is_nullable: 1

=head2 current_cycle

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id_run_annotation",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "id_run",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "id_annotation",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "run_current_ok",
  { data_type => "tinyint", extra => { unsigned => 1 }, is_nullable => 1 },
  "current_cycle",
  { data_type => "bigint", extra => { unsigned => 1 }, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_run_annotation>

=back

=cut

__PACKAGE__->set_primary_key("id_run_annotation");

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

=head2 run

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::Run>

=cut

__PACKAGE__->belongs_to(
  "run",
  "npg_tracking::Schema::Result::Run",
  { id_run => "id_run" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2023-10-23 17:02:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:l7RDTNRRvgDHqX8hxdJlQA

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

=head2 summary

Short annotation summary.

=cut

sub summary {
  my $self = shift;
  return sprintf 'Run %i annotated by %s',
    $self->id_run,
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
