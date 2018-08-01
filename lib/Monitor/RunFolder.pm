package Monitor::RunFolder;

use Moose;
use Carp;
use Readonly;

extends 'npg_tracking::illumina::runfolder';

with qw/ Monitor::Roles::Cycle
         Monitor::Roles::Username /;

our $VERSION = '0';

Readonly::Scalar our $ACCEPTABLE_CYCLE_DELAY => 6;

sub current_run_status_description {
  my ($self) = @_;
  return $self->tracking_run()->current_run_status_description();
}

sub check_cycle_count {
  my ( $self, $latest_cycle, $run_complete ) = @_;

  croak 'Latest cycle count not supplied'   if !defined $latest_cycle;
  croak 'Run complete Boolean not supplied' if !defined $run_complete;

  my $run_db = $self->tracking_run();

  $latest_cycle
    && ( $self->current_run_status_description() eq 'run pending' )
    && $run_db->update_run_status( 'run in progress', $self->username() );

  $run_complete
    && $run_db->update_run_status( 'run complete', $self->username() );

  ( $latest_cycle > $run_db->actual_cycle_count() )
    && $run_db->actual_cycle_count($latest_cycle);

  $run_db->update();

  return;
}

sub read_long_info {
  my $self = shift;

  my $run_db   = $self->tracking_run();
  my $username = $self->username();

  # Extract the relevant details.
  my $expected_cycle_count = $self->expected_cycle_count();
  my $run_is_indexed       = $self->is_indexed();
  my $run_is_paired_read   = $self->is_paired_read();

  if ( $run_db->expected_cycle_count != $expected_cycle_count ) {
    # Update the expected_cycle_count field and run tags.
    carp qq[Updating cycle count $run_db->expected_cycle_count $expected_cycle_count];
    $run_db->expected_cycle_count( $expected_cycle_count );
  }

  $run_is_paired_read ? $run_db->set_tag( $username, 'paired_read' )
                      : $run_db->set_tag( $username, 'single_read' );

  $run_is_indexed     ? $run_db->set_tag(   $username, 'multiplex' )
                      : $run_db->unset_tag( $username, 'multiplex' );

  $run_db->set_tag( $username, 'rta' ); # run is always RTA in year 2015

  $run_db->update();

  $self->_delete_lanes();

  return;
}

sub check_delay {
  my ( $self ) = @_;

  my @missing_cycles = $self->missing_cycles();

  if ( scalar @missing_cycles ) {
    carp q{Missing the following cycles: };
    carp join q{,}, @missing_cycles;
  }

  my $delay = $self->delay();

  if ( $self->delay() > $ACCEPTABLE_CYCLE_DELAY ) {
    carp q{Delayed by } . $delay . q{ cycles - this is a potential problem.};
  }

  return;
}

sub delay {
  my ( $self, $exclude_missing_cycles ) = @_;

  my $run_actual_cycles = $self->tracking_run()->actual_cycle_count();

  my $latest_cycle = $self->get_latest_cycle();

  my $delay = 0;

  if ( $run_actual_cycles != $latest_cycle ) {
    $delay = $run_actual_cycles - $latest_cycle;
    $delay =~ s/-//xms;
  }

  if ( ! $exclude_missing_cycles ) {
    my @missing_cycles = $self->missing_cycles();

    $delay += scalar @missing_cycles;
  }

  return $delay;
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

Most of the methods are provided by npg_tracking::illumina::run::short_info.

=head2 current_run_status_description

Return the current status of the object's run.

=head2 current_run_status

Return the current status (description now, object in future) of the object's run.

=head2 check_cycle_count

When passed the lastest cycle count and a boolean indicating whether the run
is complete or not, make appropriate adjustments to the database entries for
the run status and actual cycle count.

=head2 read_long_info

Use long_info to find various attributes and update run tags with the results.
The method accepts a Boolean argument indicating whether the run is RTA.

=head2 check_delay

Looks at the runfolder and sees if there are any missing cycles, and reports these,
and if the difference between the actual last cycle recorded in the database and the
highest cycle found in the runfolder on staging is greater than $ACCEPTABLE_CYCLE_DELAY
then it will report this.

=head2 delay

The number of cycles that are delayed coming across from the instrument

  actual last cycle recorded - higest cycle found on staging

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item Readonly

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
