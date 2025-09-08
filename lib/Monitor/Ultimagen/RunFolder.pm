package Monitor::Ultimagen::RunFolder;

use Moose;
use Carp;
use Readonly;
use File::Basename;
use File::Spec::Functions qw( catfile );
use DateTime;
use DateTime::Format::Strptime;

use npg_tracking::Schema;

extends 'Monitor::Ultimagen::RunParser';

with qw[
  WTSI::DNAP::Utilities::Loggable
];

our $VERSION = '0';

# Pipeline Enums
Readonly::Scalar my $USERNAME => 'pipeline';

# Run Enums
Readonly::Scalar my $RUN_UPLOADED_FILE => 'UploadCompleted.json';
Readonly::Scalar my $RUN_STATUS_MIRRORED => 'run mirrored';

Readonly::Scalar my $INSTRUMENT_NAME => 'V125';

=head1 NAME

Monitor::Ultimagen::RunFolder

=head1 VERSION

=head1 SYNOPSIS

C<<use Monitor::Ultimagen::RunFolder;
   my $run_folder = Monitor::Ultimagen::RunFolder->new(
     runfolder_path      => $run_folder,
     npg_tracking_schema => $schema
   );>>

=head1 DESCRIPTION

Run properties loader for an Ultimagen run folder. 
When a run folder is to be inspected, an instance of this class 
has to call the main function 'process_run' on it that will 
retrieve or create a run record in tracking DB.
Eventually, all run statuses will be updated accordingly.

=head1 SUBROUTINES/METHODS

=head2 npg_tracking_schema

Schema object for the tracking database connection.

=cut
has q{npg_tracking_schema}  => (
  isa        => 'npg_tracking::Schema',
  is         => q{ro},
  required   => 1,
);

=head2 tracking_run

Record representation of a run in the tracking database.

An Ultimagen run is defined by the attributes ultimagen_runid,
id_instrument.
The run related to the current run folder is retrieved from the
tracking database with these three values.
The retrieved record must be unique in the DB, otherwise it exits
with error.
When there is no record in the DB, a new run record is created
using the run attributes from runID_LibraryInfo.xml
file plus the following:
  folder_path_glob      Parent directory of the run folder
  team                  Team name. Defaults to 'SR'.
  priority              Lowest priority for a newly created run
  is_paired             A boolean attribute, is set to a false value 
                          as all runs are single ended.

Returns a Result::Run instance from which run properties can be retrieved
in the DB.

=cut
has q{tracking_run} => (
  isa           => q{npg_tracking::Schema::Result::Run},
  is            => q{ro},
  lazy          => 1,
  builder       => q{_build_tracking_run},
);
sub _build_tracking_run {
  my $self = shift;

  my $rs = $self->npg_tracking_schema->resultset('Run');
  my $run_row = $rs->find_with_attributes(
    $self->ultimagen_runid,
    $INSTRUMENT_NAME,
  );
  if ($run_row) {
    $self->info('Found run ' . $run_row->folder_name . ' with ID ' . $run_row->id_run);
    if ($run_row->folder_name ne $self->folder_name) {
      my $error = sprintf
        "Tracking run '%d - %s' has a different folder name from local folder '%s'",
        $run_row->flowcell_id, $run_row->folder_name, $self->folder_name;
      $self->logcroak($error);
    }
  } else {
    $self->info('Will create a new run for ' . $self->runfolder_path);
    my $data = {
      flowcell_id          => $self->ultimagen_runid,
      folder_name          => $self->folder_name,
      id_instrument        => $self->tracking_instrument()->id_instrument,
      folder_path_glob     => $self->runfolder_glob,
      team                 => 'SR',
      id_instrument_format => $self->tracking_instrument()->id_instrument_format,
      priority             => 1,
      is_paired            => 0,
      batch_id             => undef,
    };

    my $transaction = sub {
      $run_row = $rs->create($data);
      $self->info('Created run ' . $run_row->folder_name . ' with ID ' . $run_row->id_run);

      my $runlane_rs = $run_row->result_source()->schema()->resultset('RunLane');
      $runlane_rs->create({id_run => $run_row->id_run, position => 1});
      $self->info("Created record for lane 1 of run_id " . $run_row->id_run);

      $run_row->update_run_status(
        'run in progress', $USERNAME, $self->date_created);
      $self->_set_tags();
    };
    $rs->result_source()->schema()->txn_do($transaction);
  }
  return $run_row;
}

=head2 tracking_instrument

Record representation of an instrument in the tracking database.

The instrument record is retrieved uniquely (by DB definition).
If no instrument is found, it exits with error.

Returns a Result::Instrument instance from which instrument properties
can be retrieved in the DB.

=cut
has q{tracking_instrument} => (
  isa           => q{npg_tracking::Schema::Result::Instrument},
  is            => q{ro},
  lazy          => 1,
  builder       => q{_build_tracking_instrument},
);
sub _build_tracking_instrument {
  my $self = shift;
  my $rs = $self->npg_tracking_schema->resultset('Instrument');
  my $params = {
    external_name => $INSTRUMENT_NAME
  };
  my @instrument_rows = $rs->search($params)->all();

  my $instrument_count = scalar @instrument_rows;
  if ($instrument_count != 1) {
    $self->logcroak('No current or multiple instruments found in NPG tracking DB with name '
      . $INSTRUMENT_NAME);
  }

  my $instrument_row = $instrument_rows[0];
  $self->debug('Found instrument ' . $instrument_row->name());  
  return $instrument_row;
}

sub _set_tags {
  my ($self) = shift;
  my @tags = (
    'staging',
    'multiplex'
  );

  foreach my $tag ( @tags ) {
    $self->tracking_run()->set_tag($USERNAME, $tag);
    $self->info("$tag tag is set");
  }
}

=head2 process_run

Core function of the class that is called on the run folder
periodically to update dynamic properties of a run in the DB.
If a run record does not exist, it is created.
The tags and the following statuses are
checked/assigned accordingly:
- 'run in progress'   run is in progress on the instrument
- 'run mirrored'      all run data is copied from the instrument
                      to the staging run folder
Each of the above events saves a time stamp in the DB.

=cut
sub process_run {
  my $self = shift;
  my $run_row = $self->tracking_run();
  my $current_run_status_obj = $run_row->current_run_status;
  my $run_uploaded_path = catfile($self->runfolder_path, $RUN_UPLOADED_FILE);
  
  my $current_status_description = $current_run_status_obj->description;
  $self->info("Current run status is '$current_status_description'");
  my $current_run_status_dict = $current_run_status_obj->run_status_dict;
  
	if ( $current_run_status_dict->compare_to_status_description($RUN_STATUS_MIRRORED) == -1 ) {			
		if ( -e $run_uploaded_path ) {
      my $date = DateTime->from_epoch(epoch => (stat  $run_uploaded_path)[9]);
      $run_row->update_run_status($RUN_STATUS_MIRRORED, $USERNAME, $date);
      $self->info("Assigned '$RUN_STATUS_MIRRORED' status. "
        . 'Run ' . $self->runfolder_path . ' is now completed');
    }
	}
}

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item Readonly

=item File::Basename

=item File::Spec::Functions

=item DateTime

=item DateTime::Format::Strptime

=item npg_tracking::Schema

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
