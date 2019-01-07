use utf8;
package npg_tracking::Schema::Result::RunStatusDict;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::RunStatusDict

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

=head1 TABLE: C<run_status_dict>

=cut

__PACKAGE__->table("run_status_dict");

=head1 ACCESSORS

=head2 id_run_status_dict

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 description

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 64

=head2 iscurrent

  data_type: 'tinyint'
  default_value: 1
  extra: {unsigned => 1}
  is_nullable: 0

=head2 temporal_index

  data_type: 'smallint'
  extra: {unsigned => 1}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id_run_status_dict",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "description",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 64 },
  "iscurrent",
  {
    data_type => "tinyint",
    default_value => 1,
    extra => { unsigned => 1 },
    is_nullable => 0,
  },
  "temporal_index",
  { data_type => "smallint", extra => { unsigned => 1 }, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_run_status_dict>

=back

=cut

__PACKAGE__->set_primary_key("id_run_status_dict");

=head1 UNIQUE CONSTRAINTS

=head2 C<unique_rstdict_description>

=over 4

=item * L</description>

=back

=cut

__PACKAGE__->add_unique_constraint("unique_rstdict_description", ["description"]);

=head2 C<unique_rstdict_temporali>

=over 4

=item * L</temporal_index>

=back

=cut

__PACKAGE__->add_unique_constraint("unique_rstdict_temporali", ["temporal_index"]);

=head1 RELATIONS

=head2 run_statuses

Type: has_many

Related object: L<npg_tracking::Schema::Result::RunStatus>

=cut

__PACKAGE__->has_many(
  "run_statuses",
  "npg_tracking::Schema::Result::RunStatus",
  { "foreign.id_run_status_dict" => "self.id_run_status_dict" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-01-07 12:28:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:y62EnQAQNZ+bmHOOU2cGQA

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

use Carp;

=head2 compare_to_status_description

Comparison of run status descriptions based on their temporal_index values.
Returns -1, 0 or 1 if the temporal index of run status description is less
than, equal to or more than the temporal index for the run status description
given as an argument.

Error if the run status description given in the argument does not exist
in the table.

  print $run_status_dict_row->description(); # run_in_progress
  print $run_status_dict_row->compare_to_status_description('analysis pending'); # -1
  print $run_status_dict_row->compare_to_status_description('run in progress');  # 0
  print $run_status_dict_row->compare_to_status_description('run pending');      # 1
=cut

sub compare_to_status_description {
  my ($self, $status_desc) = @_;

  $status_desc or croak 'Non-empty status description string required';
  my $other_status_row = $self->result_source()->resultset()
                         ->find({description => $status_desc});
  if (!$other_status_row) {
    croak "Run status description '$status_desc' does not exist";
  }
  return $self->temporal_index <=> $other_status_row->temporal_index;   
}

__PACKAGE__->meta->make_immutable;

1;
