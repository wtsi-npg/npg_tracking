use utf8;
package npg_tracking::Schema::Result::EventType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

npg_tracking::Schema::Result::EventType

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

=head1 TABLE: C<event_type>

=cut

__PACKAGE__->table("event_type");

=head1 ACCESSORS

=head2 id_event_type

  data_type: 'bigint'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 description

  data_type: 'char'
  default_value: (empty string)
  is_nullable: 0
  size: 64

=head2 id_entity_type

  data_type: 'bigint'
  default_value: 0
  extra: {unsigned => 1}
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id_event_type",
  {
    data_type => "bigint",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "description",
  { data_type => "char", default_value => "", is_nullable => 0, size => 64 },
  "id_entity_type",
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

=item * L</id_event_type>

=back

=cut

__PACKAGE__->set_primary_key("id_event_type");

=head1 RELATIONS

=head2 entity_type

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::EntityType>

=cut

__PACKAGE__->belongs_to(
  "entity_type",
  "npg_tracking::Schema::Result::EntityType",
  { id_entity_type => "id_entity_type" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 event_type_services

Type: has_many

Related object: L<npg_tracking::Schema::Result::EventTypeService>

=cut

__PACKAGE__->has_many(
  "event_type_services",
  "npg_tracking::Schema::Result::EventTypeService",
  { "foreign.id_event_type" => "self.id_event_type" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 event_type_subscribers

Type: has_many

Related object: L<npg_tracking::Schema::Result::EventTypeSubscriber>

=cut

__PACKAGE__->has_many(
  "event_type_subscribers",
  "npg_tracking::Schema::Result::EventTypeSubscriber",
  { "foreign.id_event_type" => "self.id_event_type" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 events

Type: has_many

Related object: L<npg_tracking::Schema::Result::Event>

=cut

__PACKAGE__->has_many(
  "events",
  "npg_tracking::Schema::Result::Event",
  { "foreign.id_event_type" => "self.id_event_type" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BkRdBsUGse4wgTcpRHsS3A
# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: dj3 $
# Created:       2010-04-08
# Last Modified: $Date: 2010-10-07 13:00:50 +0100 (Thu, 07 Oct 2010) $
# Id:            $Id: EventType.pm 11232 2010-10-07 12:00:50Z dj3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema/Result/EventType.pm $

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 11232 $ =~ /(\d+)/mxs; $r; };

use Carp;


=head2 _entity_type_rs

Create a dbic entity_type resultset as shorthand and to access the row
validation methods in that class.

=cut

sub _entity_type_rs {
    my ($self) = @_;

    return $self->result_source->schema->resultset('EntityType')->new( {} );
}


=head2 id_query

Given an event type description and an identifier (id number or description)
for an entity type, return the id of the unique event type row, or undef if
no match is found.

=cut

sub id_query {
    my ( $self, $entity_type_identifier, $event_type_desc ) = @_;    

    croak 'Event type description required' if !defined $event_type_desc;

    my $id_entity_type = $self->_entity_type_rs->
              _insist_on_valid_row($entity_type_identifier)->id_entity_type();

    my $rs = $self->result_source->schema->resultset('EventType')->
        search(
                {
                    description    => $event_type_desc,
                    id_entity_type => $id_entity_type,
                }
        );

    return if $self->_count($rs) < 1;
    croak 'Panic! Multiple event type rows found' if $self->_count($rs) > 1;

    return $rs->first->id_event_type();
}


=head2

This method exists to be mocked. id_query calls a (similar) method which also
calls DBIx::Class::ResultSet::count, so we can't test failure in one without
triggering failure in another. Work around this by mocking this method
instead.

=cut

sub _count {
    my ($self, $result_set ) = @_;
    return $result_set->count();
}

1;




# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
