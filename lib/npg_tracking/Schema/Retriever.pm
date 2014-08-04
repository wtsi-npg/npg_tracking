package npg_tracking::Schema::Retriever;

use Moose::Role;
use Carp;
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

no Moose::Role;
1;
__END__

=head1 NAME

npg_tracking::Schema::Retriever

=head1 SYNOPSIS

=head1 DESCRIPTION

 A Moose role containing helper functions for retrieving
 single rows from dictionaries and other basic tables.

=head1 SUBROUTINES/METHODS

=head2 get_user_row

 Returns a table row representing a user. If the username is not given, but
 the flag is set to default to the pipeline user, returns a row representing
 a 'pipeline' user. If neitehr the username is given, nor the flag to use the
 defauylt user is not set, an error is raised.

 my $urow = $row->get_user_row(q[some_user]);
 my $default2pipeline_user = 1;
 my $urow = $row->get_user_row(q[], $default2pipeline_user);
 $row->get_user_row(); #throws an error

=head2 get_user_id

 Returns the id of the user. Calls get_user_row() and has the
 same interface.

=head2 pipeline_user_name

 Returns username of the pipeline user

=head2 pipeline_id

 Returns the id of the user whose username is returned by pipeline_user_name()

=head get_status_dict_row

 Returns a database row corresponding to a status given as an argument.
 The resultset name to use shoudl be given as the first argument. Valid
 for 'InstrumentStatusDict', 'RunStatusDict' and 'RunLaneStatusDict'
 resultsets. Raises an error if any of the arguments are missing and
 on a failure to retrieve a row.

 my $srow = $row->get_status_dict_row(q[RunStatusDict], q[qc complete]);

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Limited

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
