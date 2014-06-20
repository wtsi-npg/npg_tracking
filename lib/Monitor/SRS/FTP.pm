#########
# Author:        jo3
# Created:       2010-04-28

package Monitor::SRS::FTP;

use Moose;
use Monitor::RunFolder;
extends 'Monitor::SRS';

use Carp;
use English qw(-no_match_vars);
use IO::All;
use IO::All::FTP; #this package is not used explicitly
                  #it's an ftp plugin for IO::All
use List::Util qw(max);
use Readonly;

our $VERSION = '0';

Readonly::Scalar my $FTP_LOGIN     => 'ftp:srpipe';
Readonly::Scalar my $FTP_PORT      => 21;
Readonly::Scalar my $TOP_DIR       => 'Runs';
Readonly::Scalar my $LAST_ELEMENT  => -1;
Readonly::Scalar my $COMPLETE_FLAG => 'Run.complete';


has ftp_login => (
    is         => 'ro',
    isa        => 'Str',
    default    => $FTP_LOGIN,
);


has ftp_port => (
    is         => 'ro',
    isa        => 'Int',
    default    => $FTP_PORT,
);


has top_dir => (
    is         => 'ro',
    isa        => 'Str',
    default    => $TOP_DIR,
);


has ftp_root => (
    is         => 'rw',
    isa        => 'Str',
    lazy_build => 1,
);


sub _build_ftp_root {
    my ($self) = @_;

    croak 'No database entry found' if !$self->db_entry();

    my $computer = $self->db_entry->instrument_comp() || q{};
    my $login    = $self->ftp_login();
    my $port     = $self->ftp_port();

    my $address = 'ftp://' . $login . q{@} . $computer . q{:} . $port . q{/};

    return $address;
}


sub can_contact {
    my ( $self, @try_these ) = @_;

    my $contact = io( $self->ftp_root() )->all();

    foreach my $directory ( @try_these ) {
        $contact .= io( $self->ftp_root() . $directory )->all();
    }

    return $contact;
}


# IO::All::FTP throws an exception if you try to use IO::All's all_dirs
# method so we need to roll our own.
sub get_normal_run_paths {
    my ($self) = @_;

    my $path    = $self->ftp_root() . $self->top_dir() . q{/};
    my $io      = io($path);
    my $listing = $io->all();

    $self->update_latest_contact();

    my @run_paths;
    foreach my $subdir_name ( $self->all_dirs($listing) ) {

        next if !$self->validate_run_folder($subdir_name);
        push @run_paths, $path . $subdir_name;

    }

    return @run_paths;
}


sub get_latest_cycle {
    my ( $self, $run_path ) = @_;

    croak 'Run folder address required as argument' if !$run_path;


    my $status_latest = 0;
    my $status_file = "$run_path/Data/reports/StatusUpdate.xml";
    my $status_text = q{};
    eval { $status_text < io($status_file); 1 } or do {};

    if ( $status_text =~ m{ <ImgCycle> (\d+) </ImgCycle> }msx ) {
        $status_latest = $1;
    }


    my $process_ls   = io( qq{$run_path/Processed/L001} )->all();
    my $intensities_ls = io( qq{$run_path/Data/Intensities/L001} )->all();
    my $basecalls_ls = io( qq{$run_path/Data/Intensities/BaseCalls/L001} )->all();

    my @cycle_dirs = ( $self->all_dirs($process_ls),
                       $self->all_dirs($intensities_ls),
                       $self->all_dirs($basecalls_ls)
    );

    my $dirs_latest = max( 0, map { m{\bC(\d+)[.]1}msx } @cycle_dirs );


    my $latest_cycle = max( $status_latest, $dirs_latest );

    $latest_cycle
        ? $self->update_latest_contact()
        : carp "Latest cycle not found from $run_path";

    return $latest_cycle;
}


sub is_run_completed {
    my ( $self, $run_path ) = @_;

    croak 'Run folder not supplied' if !$run_path;

    my $root_list;

    eval { 
      $root_list  = io($run_path)->all(); 
      $root_list .= "\n";
      $root_list .= io("$run_path/Data")->all(); 
      1; }
        or do { carp $EVAL_ERROR; return 0; };

    if ( $root_list eq "\n" ) {
        carp "Could not read $run_path";
        return 0;
    }

    $self->update_latest_contact();

    if($root_list =~ m/\bRun[.]completed\b/msx){
      return 1;
    }

    my $rta = "RTAComplete";
    return ( $root_list =~ m/\b$rta [.]txt\b/msx ) ? 1 : 0;
}


sub is_rta {
    my ( $self, $run_path ) = @_;

    croak 'Run folder not supplied' if !$run_path;

    my $rta_test = io( "$run_path/Data/" )->all();
    return if !$rta_test;

    $self->update_latest_contact();

    return scalar @{ [ $rta_test =~ m/Intensities/gmsx ] };
}


sub update_latest_contact {
    my ($self) = @_;

    my $time_stamp = $self->mysql_time_stamp();
    $self->db_entry->latest_contact($time_stamp);
    $self->db_entry->update() or croak $OS_ERROR;

    return;
}


sub all_dirs {
    my ( $self, $listing_string ) = @_;

    my @dir_list;

    # Consider two formats of directory listings.
    foreach my $entry ( split m/\n/msx, $listing_string ) {

        next if $entry !~ m/ (?: ^d (?: [-r][-w][-xs] ){3}  )
                             |
                             <DIR>
                           /msx;

        next if $entry !~ m/ \s+ (\S+) \s* \z /msx;

        push @dir_list, $1;
    }

    return @dir_list;
}


no Moose;
__PACKAGE__->meta->make_immutable();
1;


__END__


=head1 NAME

Monitor::SRS::FTP - interrogate the host computer of an Illumina short
read sequencer via FTP.

=head1 VERSION


=head1 SYNOPSIS

    C<<use Monitor::SRS::FTP;
       my $ftp_poll = Monitor::SRS::FTP->new_with_options();    
       croak 'Host not reachable' unless $ftp_poll->can_contact();

       # Get a list of non-test, non-repeat run paths on the machine.
       my @valid_run_paths_found = $ftp_poll->get_normal_run_paths();

       # Find out how far along one of them is.
       my $actual_cycle =
            $ftp_poll->get_latest_cycle( $valid_run_paths_found[5] );

       # Get the list of subdirectories of some arbitrary directory. I.e. do
       # what IO::All::FTP::all_dirs should do.
       my @dir_list =
            $ftp_poll->all_dirs( "$valid_run_folders_found[3]/Images" );>>


=head1 DESCRIPTION

This class gets various bits of information from a GA-II sequencer's host
computer via ftp. Every time it is successful in contacting the host it notes
the time and date in a database field.

=head1 SUBROUTINES/METHODS

=head2 _build_ftp_root

Construct the ftp URL based on the computer name and the ftp login name
password.

=head2 can_contact

Try to read the 'root' directory, if it finds nothing we can take this as
evidence of failure to make the connection. Cycles through any additional
arguments appending them to the root directory. Success in any one will count
as overall success. This is for HiSeq machines where there are two run
folders.

=head2 get_normal_run_paths

Make a list of run folder paths, rejecting any that do not pass a validation
check on their names (e.g. test or re-run folders). Return the list of paths
that do validate.

=head2 get_latest_cycle

Takes a run folder address as its sole argument and returns the current cycle
number of the run.

=head2 is_run_completed

Look for the flag that indicates that a run is finished. Requires the run
path as its sole argument. Returns 1 if the flag is found, 0 otherwise.

=head2 is_rta

Return true if the run is a 'real time analysis' run. The test is whether a
subdirectory, 'Data/Intensities', exists in the runfolder.


=head2 update_latest_contact

A private method. Update the 'latest_contact' field in the database
'instrument' table.

=head2 all_dirs

IO::All::FTP has some sort of inheritance problem that means that the all_dirs
method doesn't work properly. This method tries to replace it, taking the
output of an ftp directory listing as its only argument and returning a list
of all subdirectories found there.


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
