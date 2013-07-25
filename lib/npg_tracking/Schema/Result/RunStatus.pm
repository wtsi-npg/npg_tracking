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
  is_nullable: 1

operator

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
    is_nullable => 1,
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
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 run_status_dict

Type: belongs_to

Related object: L<npg_tracking::Schema::Result::RunStatusDict>

=cut

__PACKAGE__->belongs_to(
  "run_status_dict",
  "npg_tracking::Schema::Result::RunStatusDict",
  { id_run_status_dict => "id_run_status_dict" },
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
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-07-23 16:11:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:K4FbsHr+zvJa6Gsb2KMpfg
# Author:        david.jackson@sanger.ac.uk
# Maintainer:    $Author: mg8 $
# Created:       2010-04-08
# Last Modified: $Date: 2012-04-02 15:17:16 +0100 (Mon, 02 Apr 2012) $
# Id:            $Id: RunStatus.pm 15422 2012-04-02 14:17:16Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/Schema/Result/RunStatus.pm $

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 15422 $ =~ /(\d+)/mxs; $r; };

use Carp;
use DateTime;
use DateTime::TimeZone;

=head2 description

Helper method returns the description for this run status

=cut

sub description {
  my ( $self ) = @_;
  return $self->run_status_dict->description();
}

=head2 update_run_status

Takes a hashref of arguments, and updates the current run status to requested status.
Returns the current run status dbix object

  my $oCRS = $onpg_tracking::Schema::Result::RunStatus->update_run_status({
    description => $sRunStatusDescription,
    id_user => $iIdUser,
    id_run  => $iIdRun,
  });

If you have a run status with the correct id_run and/or id_user that you want to save, then these can be left out respectively

=cut

sub update_run_status {
  my ( $self, $args ) = @_;

  my $description = $args->{description};
  croak q{No description provided} if ! defined $description;
  my $id_user     = $args->{id_user} || $self->id_user();
  my $username    = $args->{username};
  my $id_run      = $args->{id_run}  || $self->id_run();
  my $schema      = $self->result_source->schema();

  my $run = $self->id_run && $self->id_run() == $id_run ? $self->run()
          :                                               $schema->resultset( q{Run} )->search({id_run => $id_run})->first()
          ;

  # username overrides id_user
  if ( $username ) {
    $id_user = $schema->resultset( q{User} )->search({
      username => $username,
    })->first->id_user();
  }

  # do not update the run status if the current run status is already at this description
  if ( $run->current_run_status_description() eq $description ) {
    my $crs;
    foreach my $rs ( $run->run_statuses() ) {
      if ( $rs->iscurrent() ) {
        $crs = $rs;
        last;
      }
    }
    return $crs;
  }

  my $update_transaction = sub {
    foreach my $rs ( $run->run_statuses() ) {
      $rs->iscurrent( 0 );
      $rs->update();
    }
    my $desc_row = $schema->resultset( q{RunStatusDict} )->search({
      description => $description,
    })->first();

    my $new_row = $schema->resultset( q{RunStatus} )->create( {
      id_run => $id_run,
      id_run_status_dict => $desc_row->id_run_status_dict(),
      iscurrent => 1,
      id_user => $id_user,
      date => DateTime->now(time_zone=> DateTime::TimeZone->new(name => q[local])),
    } );
    $new_row->_event_update();

    return $new_row;
    
  };

  my $new_status = $schema->txn_do( $update_transaction );

  return $new_status;
}

sub _event_update {
  my ( $self ) = @_;

  my $schema = $self->result_source->schema();
  my $id_event_type = $schema->resultset( q{EventType} )->search(
    {
      'me.description' => q{status change},
      'entity_type.description' => q{run_status},
    },
    {
      'join' => q{entity_type},
    },
  )->first->id_event_type();

  my $run_name = $self->run->instrument->name() . q{_} . $self->id_run();

  my $description = $self->description() . q{ for run } . $run_name . qq{\nhttp://npg.sanger.ac.uk/perl/npg/run/$run_name\nStatus History:\n};
  foreach my $rs ( reverse $self->run->run_statuses() ) {
    $description .= q{ [} . $rs->date->ymd() . q{ } . $rs->date->hms() . q{] } . $rs->description() . qq{\n};
  }

  my $event = $schema->resultset( q{Event} )->create({
    id_event_type => $id_event_type,
    description => $description,
    entity_id => $self->id_run_status(),
    id_user => $self->id_user(),
    date => DateTime->now(time_zone=> DateTime::TimeZone->new(name => q[local])),
  });

  return $event;
}

1;



# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
