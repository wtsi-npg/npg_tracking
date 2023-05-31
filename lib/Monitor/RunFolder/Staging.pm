package Monitor::RunFolder::Staging;

use Moose;
use Carp;
use English qw(-no_match_vars);
use File::Copy;
use File::Find;
use File::Basename;
use File::Slurp;
use List::Util qw(max);
use Readonly;
use List::MoreUtils qw(any);
use Try::Tiny;
use Fcntl qw/S_ISGID/;

use npg_tracking::util::config qw(get_config_staging_areas);

extends 'Monitor::RunFolder';

our $VERSION = '0';

Readonly::Scalar my $MTIME_INDEX          => 9;
Readonly::Scalar my $SECONDS_PER_MINUTE   => 60;
Readonly::Scalar my $MINUTES_PER_HOUR     => 60;
Readonly::Scalar my $SECONDS_PER_HOUR     => $SECONDS_PER_MINUTE * $MINUTES_PER_HOUR;
Readonly::Scalar my $MAX_COMPLETE_WAIT    => 6 * $SECONDS_PER_HOUR;
Readonly::Scalar my $INTENSITIES_DIR_PATH => q[Data/Intensities];
Readonly::Scalar my $BASECALLS_DIR_PATH   => qq[$INTENSITIES_DIR_PATH/BaseCalls];
Readonly::Scalar my $MODE_INDEX           => 2;

Readonly::Scalar my $RTA_COMPLETE_FN      => q[RTAComplete.txt];
Readonly::Scalar my $COPY_COMPLETE_FN     => q[CopyComplete.txt];
Readonly::Scalar my $ONBOARD_ANALYSIS_COMPLETE_FN =>
                                             q[Secondary_Analysis_Complete.txt];
Readonly::Scalar my $ONBOARD_ANALYSIS_SAMPLESHEET_FN => q[SampleSheet.csv]; 

has 'status_update' => (isa          => 'Bool',
                        is           => 'ro',
                        default      => 1,
                       );

sub _find_file {
    my ($self, $file_path) = @_;
    my $file = join q[/], $self->runfolder_path(), $file_path;
    return -f $file ? $file : q();
}

sub is_run_complete {
    my ($self) = @_;
    
    my $rta_complete_file = $self->_find_file($RTA_COMPLETE_FN);
    my $copy_complete_file = $self->_find_file($COPY_COMPLETE_FN);
    my $is_run_complete = 0;

    if ( $rta_complete_file ) {
        if ( $self->platform_NovaSeq() or $self->platform_NovaSeqX()) {
            if ( $copy_complete_file ) {
                $is_run_complete = 1;
            } else {
                my $mtime = ( stat $rta_complete_file )[$MTIME_INDEX];
                my $last_modified = time() - $mtime;
                if  ($last_modified > $MAX_COMPLETE_WAIT) {
                    carp sprintf q[Runfolder '%s' with %s but not %s],
                        $self->runfolder_path(),
                        $RTA_COMPLETE_FN,
                        $COPY_COMPLETE_FN;
                    # Do we ever wait for this long and proceed regardless?
                    # Log to find out.
                    carp qq[Has waited for over $MAX_COMPLETE_WAIT secs, ] .
                        q[consider copied];
                    $is_run_complete = 1;
                }
            }
        } else {
            $is_run_complete = 1;
        }
    } else {
        if ( $copy_complete_file ) {
            carp sprintf q[Runfolder '%s' with %s but not %s],
                $self->runfolder_path(),
                $COPY_COMPLETE_FN,
                $RTA_COMPLETE_FN;
        }
    }

    return $is_run_complete;
}



sub is_onboard_analysis_planned {
    my $self = shift;

    my $planned = 0;
    if ($self->platform_NovaSeqX()) {
        my $ss = join q[/],
            $self->runfolder_path(), $ONBOARD_ANALYSIS_SAMPLESHEET_FN;
        my $have_ss = -f $ss;
        carp sprintf 'Samplesheet %s for the onboard analysis%sfound',
            $ss, $have_ss ? q[ ] : q[ not ];
        if ($have_ss) {
            $planned = any { $_ =~ /^\[BCLConvert/smx } read_file($ss);
            carp sprintf 'Samplesheet %s %s the BCLConvert section',
                $ss, $planned ? q[has] : q[dooen't have];
        }
    }
    return $planned;
}

sub has_onboard_analysis_finished {
    my $self = shift;

    my $analysis_dir = $self->dragen_analysis_path();
    my $found = 0;
    if (-d $analysis_dir) {
        my $file = join q[/], $analysis_dir, $ONBOARD_ANALYSIS_COMPLETE_FN;
        $found = -f $file;
        carp sprintf '%s is%sfound', $file, $found ? q[ ] : q[ not ];         
    } else {
        carp "No DRAGEN analysis directory $analysis_dir";
    }

    return $found;
}

sub monitor_stats {
    my ($self) = @_;

    my ( $total_size, $latest_mod ) = ( 0, 0 );

    find(
        sub {
                $total_size += -s $_;
                $latest_mod = max( $latest_mod, (stat)[$MTIME_INDEX] );
            },

        $self->runfolder_path()
    );

    return ( $total_size, $latest_mod );
}

sub get_latest_cycle {                                                          
    my ( $self ) = @_;
    # We assume that there will always be a lane 1 here. So far this has been
    # safe.
    my @intensities_dirs = glob
        join q[/], $self->runfolder_path, $BASECALLS_DIR_PATH, q[L001/C*];
    my @cycle_numbers =
        map { ( $_ =~ m{ L001/C (\d+) [.]1 $}gmsx ) } @intensities_dirs;
    return max( @cycle_numbers, 0 );
}

sub check_tiles {
    my ($self) = @_;

    my $expected_lanes    = $self->lane_count();
    my $expected_surfaces = $self->surface_count();
    my $expected_cycles   = $self->expected_cycle_count();
    my $expected_tiles    = $self->lane_tilecount();
    my $path              = $self->runfolder_path();

    print {*STDERR} "\tChecking Lanes, Cycles, Tiles...\n" or carp $OS_ERROR;

    my @lanes = grep { m/ L \d+ $ /msx } glob "$path/$BASECALLS_DIR_PATH/L*";
    my $l_count = scalar @lanes;
    if ( $l_count != $expected_lanes ) {
        carp "Missing lane(s) - [$expected_lanes $l_count]";
        return 0;
    }

    foreach my $lane (@lanes) {

        my @cycles  = grep { m/ C \d+ [.]1 $ /msx } glob "$lane/C*.1";
        my $c_count = scalar @cycles;
        if ( $c_count != $expected_cycles ) {
            carp "Missing cycle(s) $lane - [$expected_cycles $c_count]";
            return 0;
        }

        my $this_lane = substr $lane, -1, 1;
        if ( ! exists($expected_tiles->{$this_lane}) ) {
            carp "No expected tile count for lane $this_lane";
            return 0;
        }
        my $expected_tiles_this_lane = $expected_tiles->{$this_lane};
        my $platform_is_nv = $self->platform_NovaSeq() ||
                             $self->platform_NovaSeqX();
        my $filetype = $platform_is_nv ? 'cbcl' : 'bcl';
         
        foreach my $cycle (@cycles) {
            if ($platform_is_nv) {
                my @cbcl_files = glob "$cycle/*.$filetype" . q({,.gz});
                @cbcl_files = grep { m/ L \d+ _ \d+ [.] $filetype (?: [.] gz )? $ /msx } @cbcl_files;
                my $count = scalar @cbcl_files;
                # there should be one cbcl file per expected surface
                if ( $count != $expected_surfaces ) {
                    carp 'Missing cbcl files: '
                       . "$cycle - [expected: $expected_surfaces, found: $count]";
                    return 0;
                }
            } else {
                my @tiles   = glob "$cycle/*.$filetype" . q({,.gz});
                @tiles      = grep { m/ s_ \d+ _ \d+ [.] $filetype (?: [.] gz )? $ /msx } @tiles;
                my $t_count = scalar @tiles;
                if ( $t_count != $expected_tiles_this_lane ) {
                    carp 'Missing tile(s): '
                       . "$lane C#$cycle - [$expected_tiles_this_lane $t_count]";
                    return 0;
                }
            }
        }
    }

    return 1;
}

sub move_to_analysis {
    my ($self) = @_;

    my @ms;
    my $rf = $self->runfolder_path();
    my $destination = $self->_destination_path('incoming', 'analysis');
    my ($moved, $m) = $self->_move_folder($destination);
    push @ms, $m;
    if ($moved) {
        my $group = get_config_staging_areas()->{'analysis_group'};
        if ($group) {
            _change_group($group, $destination);
            _change_group($group, $destination . "/$INTENSITIES_DIR_PATH");
            push @ms, "Changed group to $group";
        }
        if ($self->status_update) {
            my $status = 'analysis pending';
            $self->tracking_run()->update_run_status($status);
            push @ms, "Updated Run Status to $status";
        }
    }

    return @ms;
}

sub is_in_analysis {
    my ($self) = @_;
    my $result = 1;
    try {
        $self->_destination_path('analysis', 'outgoing');
    } catch {
        if ($_ =~ 'is not in analysis') {
            $result = 0;
        }
    };
    return $result;
}

sub move_to_outgoing {
    my ($self) = @_;

    my $m;
    my $status = $self->tracking_run()->current_run_status_description();
    if ($status eq 'qc complete') {
        my $moved;
        ($moved, $m) = $self->_move_folder(
            $self->_destination_path('analysis', 'outgoing'));
    } else {
        $m = sprintf 'Run %i status %s is not qc complete, not moving to outgoing',
                     $self->tracking_run()->id_run, $status;
    }

    return $m;
}

sub _destination_path {
    my ($self, $src, $dest) = @_;
    if (!$src || !$dest) {
        croak 'Need two names';
    }

    my $new_path = $self->runfolder_path;
    my $count = $new_path =~ s{/$src/}{/$dest/}msx;
    if (!$count) {
        croak $self->runfolder_path . " is not in $src";
    }
    if ($new_path =~ m{/$src/}msx) {
        croak $self->runfolder_path . " contains multiple upstream $src directories";
    }
    if (-e $new_path) {
        croak "Path in $dest $new_path already exists";
    }

    return $new_path;
}

sub _move_folder {
    my ($self, $destination) = @_;
    if (!$destination) {
        croak 'Need destination';
    }
    my $rf = $self->runfolder_path();
    my $result = move($rf, $destination);
    my $error = $OS_ERROR;
    my $m = $result ? "Moved $rf to $destination"
                    : "Failed to move $rf to $destination: $error";
    return ($result, $m);
}

sub _get_folder_path_glob {
    my ($self) = @_;
    my $p = $self->runfolder_path;
    my $n = $self->run_folder;
    $p=~s| $n /? \Z ||smx or return;
    $p=~s{ /(incoming|analysis|outgoing)/ \Z }{/*/}smx or return;
    $p=~s/ \A \/(export|nfs)\/ /\/\{export,nfs\}\//smx;
    return $p;
}

sub _change_group {
    my ($group, $directory) = @_;

    my $temp = $directory . '.original';
    move($directory, $temp) or croak "move error: '$directory to $temp' : $ERRNO";
    mkdir $directory or croak "mkdir error: $ERRNO";
    for my $file (glob "$temp/*") {
        my $dest = $directory . q{/} . basename($file);
        move($file, $dest) or croak "move($file, $dest)\nmove error: $ERRNO";
    }
    rmdir $temp or croak "rmdir error: $ERRNO";

    my $gid = getgrnam $group;
    chown -1, $gid, $directory;
    chmod 0775, $directory;
    # If needed, add 's' to group permission so that
    # a new dir/file has the same group as parent directory
    _set_sgid($directory);

    return;
}

sub _set_sgid {
    my $directory = shift;
    my $perms = (stat($directory))[$MODE_INDEX] | S_ISGID();
    chmod $perms, $directory;
    return;
}

no Moose;
__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 NAME

Monitor::RunFolder::Staging

=head1 VERSION

=head1 SYNOPSIS

   C<<use Monitor::RunFolder::Staging;
      my $folder = Monitor:RunFolder::Staging->
                        new( runfolder_path => '/some/path' );
      print $folder->id_run();>>

=head1 DESCRIPTION

Inherits form Monitor::RunFolder and provides additional methods that are
specific to local staging (incoming) folders.

=head1 SUBROUTINES/METHODS

=head2 is_run_complete

For a non-NovaSeq(X) runfolder, it will return true if the RTAComplete.txt file
is present.

For a  NovaSeq(X) runfolder will return true if both RTAComplete.txt and
CopyComplete.txt files are present or if only RTAComplete.tx is present,
but has been there for longer than a timeout limit.

=head2 validate_run_complete

Perform a series of checks to make sure the run really is complete. Return 0
if any of them fails. If all pass return 1.

=head2 monitor_stats

Returns the sum of all file sizes in the tree below $self->runfolder_path()
and the highest epoch time found.

=head2 get_latest_cycle

=head2 check_tiles

Confirm number of lanes, cycles and tiles are as expected.

=head2 move_to_analysis

Move the run folder from 'incoming' to 'analysis'. Then set the run status to
'analysis pending'.

=head2 is_in_analysis

Returns true if the runfolder is in analysis upstream directory and
false otherwise.

=head2 move_to_outgoing

Move the run folder from 'analysis' to 'outgoing'.

=head2 is_onboard_analysis_planned

Returns true if the run folder for the NovaSeq SeriesX run contains a
samplesheet with a section for the bcl on board data conversion. Always returns
false for other instrument types.

=head2 has_onboard_analysis_finished

Returns true if the file that inticates that the onboard analysis has finished
is present in the run folder.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English

=item File::Copy

=item File::Find

=item File::Basename

=item List::Util

=item Readonly

=item Try::Tiny

=item Fcntl

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Please inform the author of any found.

=head1 AUTHOR

John O'Brien
Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013,2014,2015,2016,2018,2019,2020,2023 Genome Research Ltd.

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
