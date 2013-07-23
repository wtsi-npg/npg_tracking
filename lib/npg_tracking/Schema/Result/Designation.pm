use utf8;
package npg_tracking::Schema::Result::Designation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::Designation

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

=head1 TABLE: C<designation>

=cut

__PACKAGE__->table("designation");

=head1 ACCESSORS

=head2 id_designation

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 description

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=cut

__PACKAGE__->add_columns(
  "id_designation",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 64 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_designation>

=back

=cut

__PACKAGE__->set_primary_key("id_designation");

=head1 RELATIONS

=head2 instrument_designations

Type: has_many

Related object: L<npg_tracking::Schema::Result::InstrumentDesignation>

=cut

__PACKAGE__->has_many(
  "instrument_designations",
  "npg_tracking::Schema::Result::InstrumentDesignation",
  { "foreign.id_designation" => "self.id_designation" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZE2wjA73jXTH5Bolucxx6g
# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: gq1 $
# Created:       2010-04-08
# Last Modified: $Date: 2012-01-03 15:55:58 +0000 (Tue, 03 Jan 2012) $
# Id:            $Id: Designation.pm 14844 2012-01-03 15:55:58Z gq1 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema/Result/Designation.pm $

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14844 $ =~ /(\d+)/mxs; $r; };

=head2 instruments

Type: many_to_many

Related object: L<npg_tracking::Schema::Result::Instrument>

=cut

__PACKAGE__->many_to_many('instruments' => 'instrument_designations', 'instrument');



1;



# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
