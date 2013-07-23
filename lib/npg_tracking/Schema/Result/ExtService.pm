use utf8;
package npg_tracking::Schema::Result::ExtService;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::ExtService

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

=head1 TABLE: C<ext_service>

=cut

__PACKAGE__->table("ext_service");

=head1 ACCESSORS

=head2 id_ext_service

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 description

  data_type: 'char'
  default_value: (empty string)
  is_nullable: 0
  size: 64

=cut

__PACKAGE__->add_columns(
  "id_ext_service",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "description",
  { data_type => "char", default_value => "", is_nullable => 0, size => 64 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_ext_service>

=back

=cut

__PACKAGE__->set_primary_key("id_ext_service");

=head1 RELATIONS

=head2 event_type_services

Type: has_many

Related object: L<npg_tracking::Schema::Result::EventTypeService>

=cut

__PACKAGE__->has_many(
  "event_type_services",
  "npg_tracking::Schema::Result::EventTypeService",
  { "foreign.id_ext_service" => "self.id_ext_service" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KA1PSn0FnGqq/51NRPOqFg
# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: jo3 $
# Created:       2010-04-08
# Last Modified: $Date: 2010-09-13 18:21:28 +0100 (Mon, 13 Sep 2010) $
# Id:            $Id: ExtService.pm 10867 2010-09-13 17:21:28Z jo3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema/Result/ExtService.pm $

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 10867 $ =~ /(\d+)/mxs; $r; };

1;



# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
