#########
# Author:        jo3
# Created:       19/10/2010

package Monitor::RunFolder;

use Moose;
use Monitor::SRS::File;
with 'Monitor::Roles::Cycle';
with 'Monitor::Roles::Schema';
with 'Monitor::Roles::Username';
with 'npg_tracking::illumina::run::short_info';    # id_run

use Carp;
use English qw(-no_match_vars);
use Readonly;

our $VERSION = '0';

Readonly::Scalar our $ACCEPTABLE_CYCLE_DELAY => 6;

# short_info's documentation says that run_folder will be constrained to the
# last element of the path, so remember the input.
has runfolder_path => (
    is         => 'ro',
    isa        => 'Str',
    required   => 1,
);
with 'npg_tracking::illumina::run::long_info';   # lane, tile, cycle counts, is_rta

has run_folder => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

has run_db_row => (
    is         => 'ro',
    isa        => 'Maybe[npg_tracking::Schema::Result::Run]',
    lazy_build => 1,
);

has file_obj => (
    is         => 'ro',
    isa        => 'Monitor::SRS::File',
    lazy_build => 1,
);


sub _build_run_folder {
    my ($self) = @_;
    my $path = $self->runfolder_path();

    return substr $path, 1 + rindex( $path, q{/} );
}


sub _build_run_db_row {
    my ($self) = @_;

    my $id     = $self->id_run();
    my $run_rs = $self->schema->resultset('Run')->find($id);

    croak "Problem retrieving record for id_run => $id" if !defined $run_rs;

    return $run_rs;
}


sub current_run_status_description {
    my ($self) = @_;

    my $run_status_rs = $self->schema->resultset('RunStatus')->search(
        {
          id_run    => $self->id_run(),
          iscurrent => 1,
        }
    );

    croak 'Error getting current run status for run ' . $self->id_run()
        if $run_status_rs->count() != 1;

    return $run_status_rs->next->run_status_dict->description();
}

sub current_run_status {
    my ($self) = @_;
    carp 'DO NOT USE THIS Monitor::RunFolder::current_run_status METHOD - IMPENDING RETURN VALUE CHANGE';
    return $self->current_run_status_description();
}


sub _build_file_obj {
    my ($self) = @_;

    my $file = Monitor::SRS::File->new(
                   run_folder     => $self->run_folder(),
                   runfolder_path => $self->runfolder_path(),
    );

    return $file;
}


sub check_cycle_count {
    my ( $self, $latest_cycle, $run_complete ) = @_;

    croak 'Latest cycle count not supplied'   if !defined $latest_cycle;
    croak 'Run complete Boolean not supplied' if !defined $run_complete;

    my $run_db = $self->run_db_row();

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
    my ( $self, $run_is_rta ) = @_;

    my $recipe   = $self->file_obj();
    my $run_db   = $self->run_db_row();
    my $username = $self->username();

    eval {
        $recipe->expected_cycle_count();
        1;
    }
    or do {
        croak $EVAL_ERROR;
    };

    # Extract the relevant details.
    my $expected_cycle_count = $recipe->expected_cycle_count();
    my $run_is_indexed       = $recipe->is_indexed();
    my $run_is_paired_read   = $recipe->is_paired_read();
    ( defined $run_is_rta ) || ( $run_is_rta = $self->is_rta() );

    # Update the expected_cycle_count field and run tags.
    $run_db->expected_cycle_count( $expected_cycle_count );

    $run_is_paired_read ? $run_db->set_tag( $username, 'paired_read' )
                        : $run_db->set_tag( $username, 'single_read' );

    $run_is_indexed     ? $run_db->set_tag(   $username, 'multiplex' )
                        : $run_db->unset_tag( $username, 'multiplex' );

    $run_is_rta         ? $run_db->set_tag(   $username, 'rta' )
                        : $run_db->unset_tag( $username, 'rta' );

    $run_db->update();

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
  
  my $run_actual_cycles = $self->run_db_row()->actual_cycle_count();

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
work out various bits of information about the run. It should work on both an
FTP url and on a local path, and is called by Monitor::SRS::FTP and
Monitor::SRS::Local

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


=head1 INCOMPATIBILITIES


=head1 BUGS AND LIMITATIONS

Please inform the author of any found.

=head1 AUTHOR

John O'Brien, E<lt>jo3@sanger.ac.ukE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (C) 2010 GRL, by John O'Brien

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
