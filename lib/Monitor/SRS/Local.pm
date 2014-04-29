#########
# Author:        jo3
# Created:       2010-04-28

package Monitor::SRS::Local;

use Moose;
use Monitor::RunFolder;
extends 'Monitor::SRS';
with    'Monitor::Roles::Cycle';

use Carp;
use English qw(-no_match_vars);
use IO::All;
use IPC::System::Simple; #needed for Fatalised/autodying system()
use autodie qw(:all);

with 'npg_tracking::illumina::run::folder';

our $VERSION = '0';


has glob_pattern => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);


sub _build_glob_pattern {
    my ($self) = @_;

    my $pattern = $npg_tracking::illumina::run::folder::location::FOLDER_PATH_PREFIX_GLOB_PATTERN;

    $pattern =~ s{/ (?: IL | HS ) }{/}msx;
    $pattern =~ s{/*$}{/}msx;    # Do these two separately...
    $pattern .= q{*};            #    ...only for clarity's sake.

    return $pattern;
}


sub get_normal_run_paths {
    my ($self) = @_;

    my @all_paths;
    my $name = $self->db_entry->name();

    my %processed;
    foreach my $run_path ( glob $self->glob_pattern() ) {


        # This is a PBP bug
        ## no critic (RegularExpressions::ProhibitCaptureWithoutTest)
        next if $run_path !~ m{ incoming/ ( [^/]+ _ $name _ .+ ) }msx;
        next if $processed{$1};
        next if !$self->validate_run_folder($1);

        push @all_paths, $run_path;

        $processed{$1}++;
    }

    return @all_paths;
}


sub is_run_completed {
    my ( $self, $run_path ) = @_;

    croak 'Run folder not supplied' if !$run_path;

    my @root_list;

    # The trailing slash forces IO::All to cope with symlinks.
    eval { @root_list = io("$run_path/")->all_files(); 1; }
        or do { carp $EVAL_ERROR; return 0; };

    if ( !@root_list ) {
        carp "No files in $run_path";
        return 0;
    }

    # Using grep on @root_list doesn't work because of IO::All overloading.
    #   Check this again sometime - I don't know if that's really true.
    my $file_string = join "\n", @root_list;

    my $run_folder = Monitor::RunFolder->new( runfolder_path => $run_path, _schema => $self->schema );

    my $netcopy = 'ImageAnalysis_Netcopy_complete_Read'.scalar $run_folder->read_cycle_counts;


    return ( $file_string =~ m/\b$netcopy [.]txt\b/msx ) ? 1
         : ( $file_string =~ m/\bRun[.]completed\b/msx )          ? 1
         :                                                        0
         ;
}



no Moose;
__PACKAGE__->meta->make_immutable();
1;


__END__


=head1 NAME

Monitor::SRS::Local - interrogate the local staging area of an
Illumina short read sequencer.

=head1 VERSION


=head1 SYNOPSIS

    C<<use Monitor::SRS::Local;
       my $local_poll = Monitor::SRS::Local->new( id => $instr_id );    

       # Get a list of non-test, non-repeat, run paths on the machine.
       my @valid_run_paths_found = $local_poll->get_normal_run_paths();

       # Find out how far along one of them is.
       my $actual_cycle =
            $local_poll->get_latest_cycle( $valid_run_paths_found[5] );>>


=head1 DESCRIPTION

This class gets various bits of information from the local storage area for a
GA-II sequencer. It should broadly replicate the functionality of
Monitor::SRS::FTP so that the two can be used interchangeably (i.e. when the
FTP host is down) in an instrument monitoring script.

It has the same target as Monitor::SRS::Staging but the purposes of the two
classes are different enough to justify separate classes for simplicity's
sake. Also the methods required by the staging area monitors are not present
in Monitor::SRS::FTP, so having separate classes keeps the parallel nature of
this class to the FTP class cleaner and clearer. I hope.

=head1 SUBROUTINES/METHODS

=head2 get_normal_run_paths

Make a list of paths to run folders, rejecting any that do not pass a
validation of their names (e.g. test or re-run folders). Return the list of
paths that do pass.

=head2 get_latest_cycle

Takes a run folder address as its sole argument and returns the current cycle
number of the run.

=head2 is_run_completed

Look for the flag that indicates that a run is finished. Requires the run
path as its sole argument. Returns 1 if the flag is found, 0 otherwise.

=head1 CONFIGURATION AND ENVIRONMENT



=head1 INCOMPATIBILITIES



=head1 BUGS AND LIMITATIONS



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
