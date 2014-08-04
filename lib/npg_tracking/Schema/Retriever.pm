package npg_tracking::Schema::Retriever;

use strict;
use warnings;
use Carp;
use Moose::Role;
use Readonly;

our $VERSION = '0';

Readonly::Scalar my $PIPELINE_USER_NAME => q[pipeline];

sub get_user_row {
  my ($self, $username, $default2pipeline_user) = @_;

  if ( !$username ) {
    if ($default2pipeline_user) {
      $username = $PIPELINE_USER_NAME;
    } else {
      croak 'Username should be provided';
    }
  }

  my $row = $self->result_source->schema()->resultset('User')
              ->search({username => $username,})->next;
  if (!$row) {
    croak "User $username does not exist";
  }
  return $row;
}

sub get_user_id {
  my ($self, $username, $default2pipeline_user) = @_;
  return $self->get_user_row($username, $default2pipeline_user)->id_user;
}

sub pipeline_user_name {
  return $PIPELINE_USER_NAME;
}

=head2 pipeline_id

Convenience method to return the database id field of the username 'pipeline'.

=cut

sub pipeline_id {
  my ($self) = @_;
  return $self->get_user_row($PIPELINE_USER_NAME)->id_user;
}

sub get_status_dict_row {
  my ($self, $resultset_name, $description) = @_;

  if (!$resultset_name) {
    croak 'Resultset name should be provided';
  }  
  if (!$description) {
    croak 'Description should be provided';
  }
  my $schema = $self->result_source->schema();
  my $row = $schema->resultset($resultset_name)->search({description => $description,})->next;
  if (!$row) {
    croak "Status $description does not exist in $resultset_name";
  }
  return $row;
}


1;

