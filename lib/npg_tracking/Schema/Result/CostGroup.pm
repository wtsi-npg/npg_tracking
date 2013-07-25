use utf8;
package npg_tracking::Schema::Result::CostGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::CostGroup

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

=head1 TABLE: C<cost_group>

=cut

__PACKAGE__->table("cost_group");

=head1 ACCESSORS

=head2 id_cost_group

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 45

=cut

__PACKAGE__->add_columns(
  "id_cost_group",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 45 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_cost_group>

=back

=cut

__PACKAGE__->set_primary_key("id_cost_group");

=head1 UNIQUE CONSTRAINTS

=head2 C<name_UNIQUE>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name_UNIQUE", ["name"]);

=head1 RELATIONS

=head2 cost_codes

Type: has_many

Related object: L<npg_tracking::Schema::Result::CostCode>

=cut

__PACKAGE__->has_many(
  "cost_codes",
  "npg_tracking::Schema::Result::CostCode",
  { "foreign.id_cost_group" => "self.id_cost_group" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:k5u4HaQnGNmnkDSVIMnU6A


# You can replace this text with custom content, and it will be preserved on regeneration
# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: srpipe $
# Created:       2010-04-08
# Last Modified: $Date: 2011-08-30 09:14:49 +0100 (Tue, 30 Aug 2011) $
# Id:            $Id: CostGroup.pm 14071 2011-08-30 08:14:49Z srpipe $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema/Result/CostGroup.pm $

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14071 $ =~ /(\d+)/mxs; $r; };

1;


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
