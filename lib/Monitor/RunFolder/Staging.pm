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
Readonly::Scalar my $DEFAULT_ONBOARD_ANALYSIS_DN => q[1];
# The file with the name below flags the completion of a particular
# DRAGEN analysys. However, it's the CopyComplete.txt file in the particular
# analysis directory (/Analysis/1/, /Analysis/2/, etc.) that flags the
# completion of the analysis output to staging. In future we might track
# the DRAGEN analysis timeline, so keep this variable, though it is not
# used at the moment.
Readonly::Scalar my $ONBOARD_ANALYSIS_COMPLETE_FN =>
                                             q[Secondary_Analysis_Complete.txt];

Readonly::Array  my @UPDATES_FOR_INCOMING_ALLOWED_STATUSES =>
  ('run pending', 'run in progress', 'run complete');
Readonly::Scalar my $USERNAME => 'pipeline';

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

sub is_onboard_analysis_output_copied {

    my $self = shift;

    my $analysis_dir = $self->dragen_analysis_path();
    my $found = 0;
    if (-d $analysis_dir) {
        my $file = join q[/], $analysis_dir,
                              $DEFAULT_ONBOARD_ANALYSIS_DN, $COPY_COMPLETE_FN;
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

sub _log {
    my @ms = map { "\t$_\n" } @_;
    print {*STDOUT}  @ms or carp $OS_ERROR;
}


sub update_run_from_path { ##### Method to deal with one run folder
    my ($folder, $hash_previous_size_of,$inhibit_folder_move) = @_; # folder is like "self" - code converted from function "check_path"
    my $run_path = $folder->runfolder_path; # in case path was transformed

    my $run_status = $folder->tracking_run()->current_run_status_description();
    my $id_run = $folder->tracking_run()->id_run;

    _log("Run $id_run status $run_status");
    if ($folder->platform_NovaSeqX()) {
        _log("... run on NovaSeqX instrument");
    }

    my $db_flowcell_barcode      = $folder->tracking_run()->flowcell_id;
    my $staging_flowcell_barcode = $folder->run_flowcell; # from RunParameters.xml
    $staging_flowcell_barcode    ||= q[];
    if ($db_flowcell_barcode) { # database flowcell barcode validation
        if ($db_flowcell_barcode ne $staging_flowcell_barcode) {
            croak 'Flowcell barcode mismatch between database and staging: ' .
            join q[ ], $db_flowcell_barcode, $staging_flowcell_barcode;
        } 
    } else { # save flowcell barcode to the tracking database
        $staging_flowcell_barcode or croak
            "Staging flowcell barcode is not defined for run $id_run";
        _log("Saving staging flowcell barcode $staging_flowcell_barcode to the database.");
        $folder->tracking_run()->update({flowcell_id => $staging_flowcell_barcode});
    }

    if ($folder->is_in_analysis) {
        _log('Folder is in /analysis/');

        if( $run_status eq 'qc complete') {
            _log('Moving run folder to /outgoing/');
            (not $inhibit_folder_move) and _log($folder->move_to_outgoing());
        }
        return; # Nothing else to do for a folder in /analysis/
    }

    _log('Folder is in /incoming/');

    # If we don't remember seeing it before, set the folder name and glob;
    # set staging tag, if appropriate, set/fix instrument side, workflow side.
    # Previously we avoided making changes to the db if status was at or after
    # 'run complete'. We might consider reinstating this rule.
    if ( not defined $hash_previous_size_of->{$run_path} ) {
        $folder->update_run_record();
        $folder->tracking_run()->set_tag( $USERNAME, 'staging' );
        _log('Set staging tag');
        try {
            my $iside = $folder->set_instrument_side();
            if ($iside) {
                _log("Instrument side is set to $iside");
            }
            my $wf_type = $folder->set_workflow_type();
            if ($wf_type) {
                _log("Workflow type is set to $wf_type");
            }
            $folder->set_run_tags();
        } catch {
            _log('Error: ' . $_);
        };

        $hash_previous_size_of->{$run_path} = 0;
    }

    # Could delete the directory here. Leave it for now.
    return if $run_status eq 'data discarded';

    if (any { $run_status eq $_ } @UPDATES_FOR_INCOMING_ALLOWED_STATUSES) {
        
        my $latest_cycle = $folder->get_latest_cycle();
        if ($folder->update_cycle_count($latest_cycle)) {
            _log("Cycle count updated to $latest_cycle");
        }
        
        if ( $run_status eq 'run pending' )  {

            if ($latest_cycle) {
                $folder->update_run_status('run in progress');
                _log(q[Run status updated to 'run in progress']);
            }

        } elsif ( $run_status eq 'run in progress' ) {

            # The lane count comes from the run folder structure, which
            # we should have by now set up.
            $folder->delete_superfluous_lanes();
            if ($folder->is_run_complete()) {
                $folder->update_run_status('run complete');
                _log(q[Run status updated to 'run complete']);
            }

        } else { # run status is 'run complete'

            $folder->update_run_record(); # Inspect and update cycles,
                                          # including expected cycle count!

            if ( $folder->check_tiles($run_path) ) {

                my $previous_size = $hash_previous_size_of->{$run_path};
                my ( $current_size, $latest_mod ) = $folder->monitor_stats();
                _log(sprintf 'Run folder sizes: previous %i, current %i',
                    $previous_size, $current_size);
                $hash_previous_size_of->{$run_path} = $current_size;
 
                if ( $current_size != $previous_size ) {
                    _log('Runfolder size is still changing.');
                    return;
                }

                # Check that no file is 'in the future'.
                if ( $latest_mod > time ) {
                    _log("Files in 'future' $latest_mod are present.");
                    return;
                }

                # Check if we are waiting for the onboard analysis to finish.
                if ($folder->onboard_analysis_planned() &&
                    !$folder->is_onboard_analysis_output_copied()) {
                    return;
                }

                # Set status to 'run mirrored' and move run folder
                # from /incoming/ to /analysis/
                $folder->update_run_status('run mirrored');
                _log(q[Run status updated to 'run mirrored']);
                _log('Moving run folder to analysis');
                (not $inhibit_folder_move) and _log($folder->move_to_analysis());

                return 'done';
            }
        }
    }
   
    return;

} ###### End of method to deal with one run folder
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

=head2 is_onboard_analysis_output_copied

Returns true if the file that flags the end of the transfer of the onboard
analysis output to staging is present in the default DRAGEN analysis directory
([RUNFOLDER_NAME]/Analysis/1/ at the moment).

=head2 update_run_from_path

   C<<$folder->update_run_from_path($hash_ref_runfolder_size_state_store,
         $inhibit_folder_move);>>

Uses information found in the runfolder, dependent on its location, to update 
the tracking database. Your'll need to trace the code for the exact logic...
It will also move the run folder until the flag to inhibit this is passed.
It takes a hash ref contain the (size) state of run folders - this is (in some
logical paths) used to help determine whether certain processes have 
completed.

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
