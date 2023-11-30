use utf8;
package npg_tracking::Schema::Result::RunStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::RunStatus

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

=head1 TABLE: C<run_status>

=cut

__PACKAGE__->table("run_status");

=head1 ACCESSORS

=head2 id_run_status

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 id_run

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

=head2 id_run_status_dict

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
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

=cut

__PACKAGE__->add_columns(
  "id_run_status",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "id_run",
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
  "id_run_status_dict",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
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
);

=head1 PRIMARY KEY

=over 4

=item * L</id_run_status>

=back

=cut

__PACKAGE__->set_primary_key("id_run_status");

=head1 RELATIONS

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

=head2 run_status_dict

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::RunStatusDict>

=cut

__PACKAGE__->belongs_to(
  "run_status_dict",
  "npg_tracking::Schema::Result::RunStatusDict",
  { id_run_status_dict => "id_run_status_dict" },
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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dT2INHDh66tlPrPsaEnGaA

# Created:       2010-04-08

use List::MoreUtils qw/any/;

our $VERSION = '0';

=head2 status_dict

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::RunStatusDict>

The same as run_status_dict.

=cut

__PACKAGE__->belongs_to(
  "status_dict",
  "npg_tracking::Schema::Result::RunStatusDict",
  { id_run_status_dict => "id_run_status_dict" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 description

Status description as in the run status dictionary.

=cut

sub description {
  my ( $self ) = @_;
  return $self->run_status_dict->description();
}

=head2 summary

Short status summary.

=cut

sub summary {
  my $self = shift;
  return sprintf q[Run %i was assigned status "%s"],
    $self->id_run,
    $self->description(); 
}

=head2 information

Information about this status

=cut

sub information {
  my $self = shift;
  return sprintf q[%s on %s by %s],
    $self->summary(),
    $self->date()->strftime('%F %T'),
    $self->user()->username();
}

=head2 event_report_types

Additional event report types associated with creating a record
in this table.

=cut

sub event_report_types {
  my $self = shift;
  my @types = ();
  my $description = $self->description();
  my @statuses = ('qc review pending', 'qc complete');
  if (any { $_ eq $description} @statuses) {
    push @types, 'followers';
  }
  return @types;
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

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David Jackson E<lt>david.jackson@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013,2014,2017,2021 Genome Research Ltd.

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
