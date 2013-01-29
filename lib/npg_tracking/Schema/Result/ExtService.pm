package npg_tracking::Schema::Result::ExtService;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

npg_tracking::Schema::Result::ExtService

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


# Created by DBIx::Class::Schema::Loader v0.06001 @ 2010-09-07 09:30:15
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:R0C5O+5wddh3ERAS1pQ7AQ
# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: jo3 $
# Created:       2010-04-08
# Last Modified: $Date: 2010-09-13 18:21:28 +0100 (Mon, 13 Sep 2010) $
# Id:            $Id: ExtService.pm 10867 2010-09-13 17:21:28Z jo3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema/Result/ExtService.pm $

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 10867 $ =~ /(\d+)/mxs; $r; };

1;

