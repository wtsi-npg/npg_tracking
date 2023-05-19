package Monitor::RunFolder;

use Moose;
use Carp;
use Readonly;

extends 'npg_tracking::illumina::runfolder';

our $VERSION = '0';

Readonly::Scalar my $USERNAME => 'pipeline';

sub update_run_status {
  my ($self, $status_description) = @_;
  $self->tracking_run()
       ->update_run_status($status_description, $USERNAME);
  return;
}

sub update_cycle_count {
  my ($self, $latest_cycle) = @_;

  defined $latest_cycle or croak 'Latest cycle count not supplied';
  my $actual_cycle = $self->tracking_run()->actual_cycle_count();
  $actual_cycle ||= 0;
  if ($latest_cycle > $actual_cycle) {
    $self->tracking_run()->update({actual_cycle_count => $latest_cycle});
    return 1;
  }

  return 0;
}

sub set_instrument_side {
  my $self = shift;
  my $li_iside = $self->instrument_side;
  if ($li_iside) {
    my $db_iside = $self->tracking_run()->instrument_side || q[];
    if ($db_iside ne $li_iside) {
      my $is_set = $self->tracking_run()
                        ->set_instrument_side($li_iside, $USERNAME);
      if ($is_set) {
        return $li_iside;
      }
    }
  }
  return;
}

sub set_workflow_type {
  my $self = shift;
  my $li_wftype = $self->workflow_type;
  if ($li_wftype) {
    my $db_wftype = $self->tracking_run()->workflow_type || q[];
    if ($db_wftype ne $li_wftype) {
      my $is_set = $self->tracking_run()
                        ->set_workflow_type($li_wftype, $USERNAME);
      if ($is_set) {
        return $li_wftype;
      }
    }
  }
  return;
}

sub set_run_tags {
  my $self = shift;

  $self->is_paired_read()
    ? $self->tracking_run()->set_tag( $USERNAME, 'paired_read' )
    : $self->tracking_run()->set_tag( $USERNAME, 'single_read' );

  $self->is_indexed()
    ? $self->tracking_run()->set_tag( $USERNAME, 'multiplex' )
    : $self->tracking_run()->unset_tag( 'multiplex' );

  return;
}

sub delete_superfluous_lanes {
  my $self = shift;

  my $run_lanes = $self->tracking_run()->run_lanes;
  if ( $self->lane_count && ($self->lane_count < $run_lanes->count()) ) {
    while ( my $lane = $run_lanes->next ) {
      my $position = $lane->position;
      if ($position > $self->lane_count) {
          $lane->delete();
          carp "Deleted lane $position\n";
      }
    }
  }

  return;
}

sub update_run_record {
  my ($self) = @_;

  my $run_db = $self->tracking_run();

  my $expected_cycle_count = $self->expected_cycle_count();
  if ( $expected_cycle_count && ( ! $run_db->expected_cycle_count() ||
                                  ( $run_db->expected_cycle_count() != $expected_cycle_count ) ) ) {
    carp qq[Updating expected cycle count to $expected_cycle_count];
    $run_db->expected_cycle_count($expected_cycle_count);
  }

  if ( ! $run_db->folder_name() ) {
    my $folder_name = $self->run_folder();
    carp qq[Setting undefined folder name to $folder_name];
    $run_db->folder_name($folder_name);
  }

  my $glob = $self->_get_folder_path_glob;
  if ( $glob ) {
    $run_db->folder_path_glob($glob);
  }

  $run_db->update();

  return;
}

1;

__END__

=head1 NAME

Monitor::RunFolder - provide methods to get run details from a folder path

=head1 VERSION

=head1 SYNOPSIS

   C<<use Monitor::RunFolder;
      my $folder =
        Monitor:RunFolder->new( runfolder_path => '/some/path/or/url' );
      print $folder->run_folder();
      print $folder->id_run();>>

=head1 DESCRIPTION

When supplied a path in the constructor the class calls on various roles to
work out various bits of information about the run.

Based on these, and supplied arguments, it updates run status, run tags, etc.
for the run, creating a DBIx record object to do that.

=head1 SUBROUTINES/METHODS

=head2 update_cycle_count

If necessary, updates actual run cycle count. If the count has not advanced
compared to the database record, the record not updated. Returns true if the
cycle count has been updated, false otherwise.

  $folder->update_cycle_count(3);

=head2 update_run_status

Updates run status.

  $folder->update_run_status('run in progress');

=head2 set_instrument_side

Retrieves instrument side from {r|R}unParamaters.xml file and sets
a relevant run tag if the tag is not yet set or does not match the
value in the parameters file.

Returns the instrument side string if it has been changed, an undefined
value otherwise.

=head2 set_workflow_type

Retrieves workflow from {r|R}unParamaters.xml file and sets
a relevant run tag if the tag is not yest set or does not match the
value in the parameters file.

Returns the workflow type string if it has been changed, an undefined
value otherwise.

=head2 set_run_tags

Sets multiplex, paired or single read tags as appropriate.

=head2 delete_superfluous_lanes

Deletes database run_lane table records for lanes not present in a run folder.

=head2 update_run_record

Ensures DB has updated runfolder name and a suitable glob for quickly
finding the run folder. Updates extected cycle count value if needed.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item John O'Brien

=item Marina Gourtovaia

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013,2014,2015,2018,2019,2020,2023 Genome Research Ltd.

This program is free software: you can redistribute it and/or modify
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
