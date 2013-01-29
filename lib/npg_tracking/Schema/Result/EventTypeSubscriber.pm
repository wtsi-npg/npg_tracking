package npg_tracking::Schema::Result::EventTypeSubscriber;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 NAME

npg_tracking::Schema::Result::EventTypeSubscriber

=cut

__PACKAGE__->table("event_type_subscriber");

=head1 ACCESSORS

=head2 id_event_type_subscriber

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 id_event_type

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=head2 id_usergroup

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id_event_type_subscriber",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "id_event_type",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
  "id_usergroup",
  {
    data_type => "bigint",
    default_value => 0,
    extra => { unsigned => 1 },
    is_foreign_key => 1,
    is_nullable => 0,
  },
);
__PACKAGE__->set_primary_key("id_event_type_subscriber", "id_usergroup", "id_event_type");

=head1 RELATIONS

=head2 event_type

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::EventType>

=cut

__PACKAGE__->belongs_to(
  "event_type",
  "npg_tracking::Schema::Result::EventType",
  { id_event_type => "id_event_type" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 usergroup

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::Usergroup>

=cut

__PACKAGE__->belongs_to(
  "usergroup",
  "npg_tracking::Schema::Result::Usergroup",
  { id_usergroup => "id_usergroup" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.06001 @ 2010-09-07 09:30:15
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zeL3MbqjZH4s3UyNfRu62Q
# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: jo3 $
# Created:       2010-04-08
# Last Modified: $Date: 2010-09-13 18:21:28 +0100 (Mon, 13 Sep 2010) $
# Id:            $Id: EventTypeSubscriber.pm 10867 2010-09-13 17:21:28Z jo3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema/Result/EventTypeSubscriber.pm $

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 10867 $ =~ /(\d+)/mxs; $r; };

1;

