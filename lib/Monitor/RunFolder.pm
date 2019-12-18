package Monitor::RunFolder;

use Moose;
use Carp;

extends 'npg_tracking::illumina::runfolder';
with qw/ Monitor::Roles::Username /;

our $VERSION = '0';

sub update_cycle_count_and_run_status {
  my ( $self, $latest_cycle, $run_complete ) = @_;

  croak 'Latest cycle count not supplied'   if !defined $latest_cycle;
  croak 'Run complete Boolean not supplied' if !defined $run_complete;

  my $run_db = $self->tracking_run();

  $latest_cycle
    && ( $run_db->current_run_status_description() eq 'run pending' )
    && $run_db->update_run_status( 'run in progress', $self->username() );

  $run_complete
    && $run_db->update_run_status( 'run complete', $self->username() );

  if ( $latest_cycle > $run_db->actual_cycle_count() ) {
    $run_db->update({actual_cycle_count => $latest_cycle});
  }

  return;
}

sub set_instrument_side {
  my $self = shift;
  my $li_iside = $self->instrument_side;
  if ($li_iside) {
    my $db_iside = $self->tracking_run()->instrument_side || q[];
    if ($db_iside ne $li_iside) {
      my $is_set = $self->tracking_run()
                        ->set_instrument_side($li_iside, $self->username());
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
                        ->set_workflow_type($li_wftype, $self->username());
      if ($is_set) {
        return $li_wftype;
      }
    }
  }
  return;
}

sub read_long_info {
  my $self = shift;

  my $run_db   = $self->tracking_run();

  my $expected_cycle_count = $self->expected_cycle_count();
  my $db_expected = $run_db->expected_cycle_count;
  if ( $db_expected != $expected_cycle_count ) {
    warn qq[Updating cycle count $db_expected to $expected_cycle_count\n];
    $run_db->update({expected_cycle_count => $expected_cycle_count});
  }

  $self->is_paired_read() ? $run_db->set_tag( $self->username, 'paired_read' )
                          : $run_db->set_tag( $self->username, 'single_read' );

  $self->is_indexed() ? $run_db->set_tag( $self->username, 'multiplex' )
                      : $run_db->unset_tag( 'multiplex' );

  $self->_delete_lanes();

  return;
}

sub _delete_lanes {
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

=head2 update_cycle_count_and_run_status

When passed the lastest cycle count and a boolean indicating whether the run
is complete or not, make appropriate adjustments to the database entries for
the run status and actual cycle count.

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

=head2 read_long_info

Use long_info to find various attributes and update run tags with the results.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Please inform the author of any found.

=head1 AUTHOR

=over

=item John O'Brien, E<lt>jo3@sanger.ac.ukE<gt>

=item Marina Gourtovaia

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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
