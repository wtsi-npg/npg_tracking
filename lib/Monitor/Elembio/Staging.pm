package Monitor::Elembio::Staging;

use Moose;
use Carp;
use MooseX::StrictConstructor;
use Cwd 'abs_path';
use File::Spec::Functions 'catfile';
use Monitor::Elembio:RunFolder qw ( get_run_parameter );
use npg_tracking::Schema;

with qw[
        WTSI::DNAP::Utilities::Loggable
    ];

our $VERSION = '0';

has schema => (
    is         => 'ro',
    required   => 1,
    isa        => 'npg_tracking::Schema',
);

sub find_run_folders {
    my ( $self, $staging_area ) = @_;

    $self->logcroak('Top level staging path required') if !$staging_area;
    $self->logcroak("$staging_area not a directory") if !-d $staging_area;

    my @run_folders;
    my $manifest_pattern = catfile($staging_area, 'AV*/**/RunManifest.json')
    foreach my $run_manifest_file ( glob $manifest_pattern ) {
        my $run_dir = dirname(abs_path($run_manifest_file))
        if (! -d $run_dir) next;
        $self->debug("Found run folder: $run_dir");

        next if (! get_run_parameter_file($run_dir));
        push @run_folders, $run_dir
        # Check run folder is valid for elembio #
        # which contain real data #
    }
    return @run_folders;
}


sub monitor_run_status {
    my ($run_folder, $dry_run) = @_;
    my $run_row = get_run_from_tracking($run_folder) # creates a run if doesn't exist

    my $monitored_runfolder = Monitor::Elembio::RunFolder->new(runfolder_path      => $run_folder,
                                                                npg_tracking_schema => $self->schema,
                                                                dry_run => $dry_run);
    if (! $monitored_runfolder) {
        $self->logcarp("RunFolder creation failed")  
        return 0;
    }
    $monitored_runfolder->update_remote_run_parameters();
    # Get run row from schema (through new run Identification object composition)
    # Check monitored_runfolder
    # Check Run Identification Object Composition
    # if does not exist -> skip
    # otherwise...
    #   Check in DB and staging folder:
    #       - instrument_name
    #       - folder_name
    #       - flowcell_id
    #   If do not match -> skip
    #   Otherwise, add the run folder to array
    return 1;
}

__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 NAME

Monitor::Elembio::Staging

=head1 VERSION

=head1 SYNOPSIS

    C<<use Monitor::Elembio::Staging;
       my $stage_poll = Monitor::Elembio::Staging->new();>>

=head1 DESCRIPTION

Interrogate the staging area designated to an Elembio instrument.

=head1 SUBROUTINES/METHODS

=head2 validate_areas

Check if the argument passed to the method is a valid staging area.
Error if no argument or multiple arguments are given.

=head2 find_live

Take a staging area path as a required argument and return a list of all run
directories found in it.

The path pattern should match [staging_area]/AV*/[run_folder]


=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Carp

=item Try::Tiny

=item MooseX::StrictConstructor

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Marco M. Mosca

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2025 Genome Research Ltd.

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
