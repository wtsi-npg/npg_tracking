use utf8;
package npg_tracking::Schema::Result::RunLaneStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::RunLaneStatus

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

=head1 TABLE: C<run_lane_status>

=cut

__PACKAGE__->table("run_lane_status");

=head1 ACCESSORS

=head2 id_run_lane_status

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_run_lane

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

=head2 iscurrent

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 id_run_lane_status_dict

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id_run_lane_status",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "id_run_lane",
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
  "iscurrent",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "id_run_lane_status_dict",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_run_lane_status>

=back

=cut

__PACKAGE__->set_primary_key("id_run_lane_status");

=head1 RELATIONS

=head2 run_lane

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::RunLane>

=cut

__PACKAGE__->belongs_to(
  "run_lane",
  "npg_tracking::Schema::Result::RunLane",
  { id_run_lane => "id_run_lane" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 run_lane_status_dict

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::RunLaneStatusDict>

=cut

__PACKAGE__->belongs_to(
  "run_lane_status_dict",
  "npg_tracking::Schema::Result::RunLaneStatusDict",
  { id_run_lane_status_dict => "id_run_lane_status_dict" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 user

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "npg_tracking::Schema::Result::User",
  { id_user => "id_user" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2014-02-20 10:43:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TkFv5J36/M51WwS1WQKs8Q

# Created:       2010-04-08

our $VERSION = '0';

=head2 status_dict

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::RunLaneStatusDict>

The same as run_lane_status_dict

=cut

__PACKAGE__->belongs_to(
  "status_dict",
  "npg_tracking::Schema::Result::RunLaneStatusDict",
  { id_run_lane_status_dict => "id_run_lane_status_dict" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 description

returns the status description directly as a helper method, rather than forcing you to go through the run_lane_status_dict manually

=cut

sub description {
  my ( $self ) = @_;
  return $self->run_lane_status_dict()->description();
}

=head2 id_run

returns the id_run this lane is on directly, rather than forcing you through the run_lane manually

=cut

sub id_run {
  my ( $self ) = @_;
  return $self->run_lane()->id_run();
}

=head2 position

returns the position of this lane is directly, rather than forcing you through the run_lane manually

=cut

sub position {
  my ( $self ) = @_;
  return $self->run_lane()->position();
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

Result class definition in DBIx binding for npg tracking database.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose

=item MooseX::NonMoose

=item MooseX::MarkAsMethods

=item DBIx::Class::Core

=item DBIx::Class::InflateColumn::DateTime

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David Jackson E<lt>david.jackson@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Limited

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.

=cut
