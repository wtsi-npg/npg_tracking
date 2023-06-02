package Monitor::Staging;

use Moose;
use namespace::autoclean;
use Carp;
use Try::Tiny;
use MooseX::StrictConstructor;

use npg_tracking::illumina::run::folder::validation;
use Monitor::RunFolder;

our $VERSION = '0';

has schema => (
    is         => 'ro',
    required   => 1,
    isa        => 'npg_tracking::Schema',
);

sub validate_areas {
    my ( $self, @staging_areas ) = @_;

    if (!@staging_areas) {
        croak 'Empty argument list of staging areas';
    }
    if (@staging_areas > 1) {
        croak 'Multiple staging areas cannot be processed';
    }
    my $staging_area = $staging_areas[0];
    if ( !-d $staging_area ) {
        croak "Staging directory not found: $staging_area";
    }
   
    return $staging_area;
}


sub find_live {
    my ( $self, $staging_area ) = @_;

    croak 'Top level staging path required' if !$staging_area;
    croak "$staging_area not a directory"   if !-d $staging_area;

    my %path_for;

    foreach my $run_dir ( glob $staging_area . q{/IL*/{incoming,analysis}/*} ) {

        warn "\n\nFound $run_dir\n";

        if (-d $run_dir) {
            my $check = Monitor::RunFolder->new(runfolder_path      => $run_dir,
                                                npg_tracking_schema => $self->schema);
            my $run_folder = $check->run_folder();

            my $id_run;
            try {
                $id_run = $check->id_run();
                warn "Retrieved id_run $id_run\n";
            } catch {
                warn "Skipping $run_dir - error retrieving id_run\n";
            };

            my $run_row = $self->schema->resultset('Run')->find({ id_run => $id_run });
            if (! $run_row ) {
                if ( ! defined $id_run ) {
                    warn qq[ID run is undefined, skipping\n];
                } else {
                    warn qq[ID Run '$id_run' not found in database, skipping\n];
                }
            } else {
                if (! $run_row->folder_name ) {
                  warn qq[Folder name in db not available, will try to update using '$run_folder'.];
                  # check the id_run corresponds to a run with a status of "run pending" to reduce the
                  # chance of incorrect updates if an incorrect id_run is entered by the loaders e.g. missing
                  # digit so that it matches an old run which is "run canceled" such that the automatic run
                  # folder deletion process would start removing it...
                  # If a run is canceled (or run status changed) before this, the runfolder may not be processed
                  # automatically...
                  my $run_status = $run_row->current_run_status_description();
                  if ( $run_status ne qq[run pending] ) {
                      warn "Skipping $run_dir - the id_run $id_run may be wrong" .
                           " as this run has a status of $run_status\n";
                      next;
                  }
                  # check the instrument name is what is expected for this run
                  my $db_external_name = $run_row->instrument->external_name();
                  if (! $db_external_name ){
                      warn qq[No instrument external_name for '$id_run' found in database, skipping\n];
                      next;
                  }
                  my $staging_instrument_name;
                  try {
                      $staging_instrument_name = $check->instrument_name(); # from RunInfo.xml
                      warn "Retrieved instrument_name $staging_instrument_name\n";
                  } catch {
                      warn "error retrieving instrument_name from RunInfo.xml\n";
                  };
                  if ( ! defined $staging_instrument_name ) {
                      warn "instrument_name is undefined, skipping $run_dir\n";
                      next;
                  } else {
                      if ($db_external_name ne $staging_instrument_name) {
                          warn "Skipping $run_dir - instrument name mismatch" .
                             " for run $id_run, '$staging_instrument_name' on staging," .
                             " '$db_external_name' in the database.\n";
                          next;
                      }
                      $run_row->update({'folder_name' => $run_folder}); # or validation will fail
                  }
                }    
                if ( npg_tracking::illumina::run::folder::validation->new(
                         run_folder          => $run_folder,
                         id_run              => $id_run,
                         npg_tracking_schema => $self->schema )->check() ) {
                    $path_for{$id_run} = $run_dir;
                    warn "Cached $run_dir for run $id_run\n";
                } else {
                    warn "Skipping $run_dir - not valid\n";
                }
            }
        } else {
            warn "Skipping $run_dir - is not a directory\n";
        }
    }

    # Remove any folders belonging to cancelled runs.
    my $run_status_rs = $self->schema->resultset('RunStatus')->search(
        {
            'run_status_dict.description' => 'run cancelled',
            'me.id_run '                  => { '-in' => [ keys %path_for ] },
            'me.iscurrent'                => 1,
        },
        {
            join => 'run_status_dict',
        }
    );

    while ( my $run_status_row = $run_status_rs->next() ) {
        my $cancelled_run_id = $run_status_row->id_run();

        if ( defined $path_for{$cancelled_run_id} ) {
            delete $path_for{$cancelled_run_id};
        }
    }

    return values %path_for;
}

__PACKAGE__->meta->make_immutable();

1;

__END__

=head1 NAME

Monitor::Staging - interrogate the staging area designated to an Illumina
short read sequencer.

=head1 VERSION

=head1 SYNOPSIS

    C<<use Monitor::Staging;
       my $stage_poll = Monitor::Staging->new();>>

=head1 DESCRIPTION

This class gets various bits of information from the staging area for a short
read sequencer.

=head1 SUBROUTINES/METHODS

=head2 validate_areas

Check if the argument passed to the method is a valid staging areas,
ie an existing directory. Error if no argument or multiple arguments
is/are given.

=head2 find_live

Take a staging area path as a required argument and return a list of all run
directories (no tests or repeats) found in incoming and analysis folders below
it.

The path pattern should match /[staging_area]/IL*/{incoming, analysis}/[run_folder]


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
