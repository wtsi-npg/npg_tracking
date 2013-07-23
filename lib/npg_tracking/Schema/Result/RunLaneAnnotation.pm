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
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

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


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uIpg3AS/VOzbk6wv3a2mjw
# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: dj3 $
# Created:       2010-04-08
# Last Modified: $Date: 2010-11-08 15:02:27 +0000 (Mon, 08 Nov 2010) $
# Id:            $Id: RunLaneAnnotation.pm 11663 2010-11-08 15:02:27Z dj3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema/Result/RunLaneAnnotation.pm $

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 11663 $ =~ /(\d+)/mxs; $r; };

1;



# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
