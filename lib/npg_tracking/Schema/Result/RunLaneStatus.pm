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

# Author:        david.jackson@sanger.ac.uk
# Created:       2010-04-08

our $VERSION = '0';

use Carp;
use DateTime;
use DateTime::TimeZone;

=head2 description

returns the status description directly as a helper method, rather than forcing you to go through the run_lane_status_dict manually

=head2 id_run

returns the id_run this lane is on directly, rather than forcing you through the run_lane manually

=head2 position

returns the position of this lane is directly, rather than forcing you through the run_lane manually

=cut

sub description {
  my ( $self ) = @_;
  return $self->run_lane_status_dict()->description();
}

sub id_run {
  my ( $self ) = @_;
  return $self->run_lane()->id_run();
}

sub position {
  my ( $self ) = @_;
  return $self->run_lane()->position();
}

=head2 update_run_lane_status

Takes a hashref of arguments, and updates the current run_lane_status to the selected status, and non_currents all other statuses for this lane

  $onpg_tracking::Schema::Result::RunLaneStatus=HASH...->update_run_lane_status({
    id_run => 1,
    position => 7,
    username => 'joe_annotator',
    description => 'analysis complete',
  });
  $onpg_tracking::Schema::Result::RunLaneStatus=HASH...->update_run_lane_status({
    id_run_lane => 1,
    id_user => 5,
    description => 'analysis complete',
  });

Either id_run & position or id_run_lane can be given, but one must be
Either username or id_user can be given, but one must be
A description must be provided

=cut

sub update_run_lane_status {
  my ( $self, $args ) = @_;

  my $id_run = $args->{id_run};
  my $position = $args->{position};
  my $description = $args->{description};
  my $id_run_lane = $args->{id_run_lane};
  my $id_user = $args->{id_user};
  my $username = $args->{username};

  my $schema = $self->result_source->schema();

  if ( ! $description ) {
    croak q{No description provided};
  }
  if ( ! $id_run_lane && ! ( $id_run && $position ) ) {
    croak q{No lane information provided};
  }

  if ( ! ( $id_user || $username ) ) {
    croak q{no user provided}
  }

  my $run_lane_row;
  if ( ! $id_run_lane ) {
    $run_lane_row = $schema->resultset( q{RunLane} )->find({
      id_run => $id_run,
      position => $position,
    });
    $id_run_lane = $run_lane_row->id_run_lane();
    croak qq{no row exists for run lane id_run: $id_run, position: $position} if ! $id_run_lane;
  } else {
    $run_lane_row = $schema->resultset( q{RunLane} )->find({
      id_run_lane => $id_run_lane,
    });
  }

  if ( ! $id_user ) {
    $id_user = $schema->resultset( q{User} )->find({
      username => $username,
    })->id_user();
    croak qq{no row exists for user $username} if ! $id_user;
  }

  my $update_transaction = sub {
    $run_lane_row->related_resultset( q{run_lane_statuses} )->update_all({iscurrent=>0});
    my $desc_row = $schema->resultset( q{RunLaneStatusDict} )->find({
      description => $description,
    });
    my $new_row = $run_lane_row->related_resultset( q{run_lane_statuses} )->create( {
      run_lane_status_dict => $desc_row,
      iscurrent => 1,
      id_user => $id_user,
      date => DateTime->now(time_zone=> DateTime::TimeZone->new(name => q[local])),
    } );

    $new_row->_update_run_status();

    return $new_row;
  };
  
  my $new_status = $schema->txn_do( $update_transaction );

  return $new_status;
}

sub _update_run_status {
  my ( $self ) = @_;

  my $description = $self->description();

  if ( $description ne q{analysis complete}
         &&
       $description ne q{manual qc complete} ) {  return 1; }     

  my $schema = $self->result_source->schema();
  my $run    = $self->run_lane->run();
  my $id_run_lane_status_dict = $self->id_run_lane_status_dict();

  my $lane_count = scalar $run->run_lanes();
  my $updated_to_same_status_count = 0;
  foreach my $lane ( $run->run_lanes() ) {
    if ( my$crls = $lane->current_run_lane_status ) {
      if ( $crls->description() eq $description ) {
        $updated_to_same_status_count++;
      }
    }
  }

  if ( $updated_to_same_status_count == $lane_count ) {
    my $first_run_status = $run->run_statuses()->first();

    if ( $description eq q{analysis complete} ) {
      my $row = $first_run_status->update_run_status({
        description => q{analysis complete},
        id_user => $self->id_user(),
      });
      $first_run_status->update_run_status({
        description => q{qc review pending},
        id_user => $self->id_user(),
      });
    } else {
      $first_run_status->update_run_status({
        description => q{archival pending},
        id_user => $self->id_user(),
      });
    }

    carp q{All updated};
  } else {
    carp $lane_count - $updated_to_same_status_count . q{ lanes not yet updated to this status};
  }

  return 1;
}

__PACKAGE__->meta->make_immutable;
1;
