package Monitor::Elembio::RunFolder;

use Moose;
use Carp;
use Readonly;
use JSON;
use File::Basename;
use File::Spec::Functions qw( catfile catdir );
use DateTime;
use List::Util qw( sum );
use List::MoreUtils qw( any );
use DateTime::Format::Strptime;
use Perl6::Slurp;
use Try::Tiny;

use npg_tracking::Schema;
use npg_tracking::util::types;

with qw[
  WTSI::DNAP::Utilities::Loggable
];

our $VERSION = '0';

# Pipeline Enums
Readonly::Scalar my $USERNAME => 'pipeline';

# Property Enums
Readonly::Scalar my $CONSUMABLES => 'Consumables';
Readonly::Scalar my $CYCLES => 'Cycles';
Readonly::Scalar my $CYCLES_I1 => 'I1';
Readonly::Scalar my $CYCLES_R2 => 'R2';
Readonly::Scalar my $CYCLE_FILE_PATTERN => qr/^[IR][12]_C\d{3}/;
Readonly::Scalar my $CYCLE_FILE_PATTERN_CYTO => qr/^[B]\d{2}_C\d{3}/;
Readonly::Scalar my $DATE => 'Date';
Readonly::Scalar my $FLOWCELL => 'Flowcell';
Readonly::Scalar my $FOLDER_NAME => 'RunFolderName';
Readonly::Scalar my $INSTRUMENT_NAME => 'InstrumentName';
Readonly::Scalar my $LANES => 'AnalysisLanes';
Readonly::Scalar my $RUN_NAME => 'RunName';
Readonly::Scalar my $SERIAL_NUMBER => 'SerialNumber';
Readonly::Scalar my $SIDE => 'Side';
Readonly::Scalar my $TIME_PATTERN => '%Y-%m-%dT%H:%M:%S.%NZ'; # 2023-12-19T13:31:17.461926614Z
Readonly::Scalar my $RUN_STATUS_TIME_PATTERN => '%Y-%m-%dT%H:%M:%S';

# Run Uploaded Enums
Readonly::Scalar my $OUTCOME => 'outcome';
Readonly::Scalar my $OUTCOME_COMPLETE => 'OutcomeCompleted';
Readonly::Scalar my $OUTCOME_FAILED => 'OutcomeFailed';

# Run Enums
Readonly::Scalar my $RUN_CYTOPROFILE => 'Cytoprofiling';
Readonly::Scalar my $RUN_PARAM_FILE => 'RunParameters.json';
Readonly::Scalar my $RUN_TYPE => 'RunType';
Readonly::Scalar my $RUN_UPLOAD_FILE => 'RunUploaded.json';
Readonly::Scalar my $RUN_STATUS_ARCHIVAL_PENDING => 'archival pending';
Readonly::Scalar my $RUN_STATUS_ARCHIVED => 'run archived';
Readonly::Scalar my $RUN_STATUS_CANCELLED => 'run cancelled';
Readonly::Scalar my $RUN_STATUS_COMPLETE => 'run complete';
Readonly::Scalar my $RUN_STATUS_INPROGRESS => 'run in progress';
Readonly::Scalar my $RUN_STATUS_STOPPED => 'run stopped early';
Readonly::Scalar my $RUN_STATUS_TYPE => 'StatusType';

=head1 NAME

Monitor::Elembio::RunFolder

=head1 VERSION

=head1 SYNOPSIS

C<<use Monitor::Elembio::RunFolder;
   my $run_folder = Monitor::Elembio::runfolder->new(
     runfolder_path      => $run_folder,
     npg_tracking_schema => $schema
   );>>

=head1 DESCRIPTION

Properties loader for an Elembio run folder.

=head1 SUBROUTINES/METHODS

=head2 runfolder_path

Path of the run folder.

=cut
has q{runfolder_path} => (
  isa           => q{Str},
  is            => q{ro},
  required      => 1,
);

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

An Elembio run is defined by the attributes flowcell_id, folder_name,
id_instrument.
The run related to the current run folder is retrieved from the
tracking database with these three values.
The retrieved record must be unique in the DB, otherwise it exits
with error.
When there is no record in the DB, a new run record is created
using the run attributes from RunParameters.json
file plus the following:
  folder_path_glob      Parent directory of the run folder
  expected_cycle_count  Expected number of cycles from the RunParameters.json
  team                  Team name. Defaults to 'SR'.
  priority              Lowest priority for a newly created run
  is_paired             A boolean attribute, is set to a true value 
                          if the run is a paired read.
During the run creation, lanes are created in 'RunLane' table and their
number is retrieved from the RunParameters.json.

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

  my $run_row = $self->find_run_db_record();
  if ($run_row) {
    $self->info('Found run ' . $run_row->folder_name . ' with ID ' . $run_row->id_run);
  } else {
    my $rs = $self->npg_tracking_schema->resultset('Run');
    $self->info('will create a new run for ' . $self->runfolder_path);
    my $data = {
      flowcell_id          => $self->flowcell_id,
      folder_name          => $self->folder_name,
      id_instrument        => $self->tracking_instrument()->id_instrument,
      folder_path_glob     => dirname($self->runfolder_path),
      expected_cycle_count => $self->expected_cycle_count,
      actual_cycle_count   => 0,
      team                 => 'SR',
      id_instrument_format => $self->tracking_instrument()->id_instrument_format,
      priority             => 1,
      is_paired            => $self->is_paired,
      batch_id             => $self->batch_id,
    };

    my $transaction = sub {
      $run_row = $rs->create($data);
      $self->info('Created run ' . $run_row->folder_name . ' with ID ' . $run_row->id_run);

      my $runlane_rs = $run_row->result_source()->schema()->resultset('RunLane');
      for my $lane (1 .. $self->lane_count) {
        $runlane_rs->create({id_run => $run_row->id_run, position => $lane});
        $self->info("Created record for lane $lane of run_id " . $run_row->id_run);
      }
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
    external_name => $self->instrument_name
  };
  my @instrument_rows = $rs->search($params)->all();

  my $instrument_count = scalar @instrument_rows;
  if ($instrument_count == 0) {
    $self->logcroak('No current instrument found in NPG tracking DB with name ' . $self->instrument_name);
  }

  my $instrument_row = $instrument_rows[0];
  $self->debug('Found instrument ' . $instrument_row->name());  
  return $instrument_row;
}

=head2 flowcell_id

A string containing the flowcell ID used for the sequencing.
It is retrieved from RunParameters.json file.

=cut
has q{flowcell_id}  => (
  isa             => q{Str},
  is              => q{ro},
  required        => 0,
  lazy_build      => 1,
);
sub _build_flowcell_id {
  my $self = shift;
  my $flowcell_id = $self->_run_params_data()->{$CONSUMABLES}->{$FLOWCELL}->{$SERIAL_NUMBER};
  if (! $flowcell_id) {
    $self->logcroak('Empty value in flowcell_id');
  }
  return $flowcell_id;
}

=head2 folder_name

A string containing a time stamp, flowcell_id and run name
that define a run. It is retrieved from RunParameters.json file.

=cut
has q{folder_name}    => (
  isa               => q{Str},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
);
sub _build_folder_name {
  my $self = shift;
  my $folder_name = $self->_run_params_data()->{$FOLDER_NAME};
  if (! $folder_name) {
    $self->logcroak('Empty value in folder_name');
  }
  return $folder_name;
}

=head2 instrument_name

A unique (external) name assigned to the instrument
and retrieved from RunParameters.json file.

=cut
has q{instrument_name}  => (
  isa               => q{Str},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
);
sub _build_instrument_name {
  my $self = shift;
  return $self->_run_params_data()->{$INSTRUMENT_NAME};
}

=head2 instrument_side

The instrument side where the sequencing is performed.
It is retrieved from RunParameters.json file.

=cut
has q{instrument_side}     => (
  isa           => q{Str},
  is            => q{ro},
  required      => 0,
  lazy_build    => 1,
);
sub _build_instrument_side {
  my $self = shift;
  my ($side) = $self->_run_params_data()->{$SIDE} =~ /Side(A|B)/smx;
  if (!$side) {
    $self->logcroak("Run parameter $SIDE: wrong format in $RUN_PARAM_FILE");
  }
  return $side;
}

=head2 batch_id

The sequencing batch ID. It is retrieved from the run name
of the RunParameters.json file.

Not being able to extract batch ID from the run name is not 
an error. Walk-up runs are not tracked through LIMS.

=cut
has q{batch_id}     => (
  isa           => q{Maybe[NpgTrackingPositiveInt]},
  is            => q{ro},
  required      => 0,
  lazy_build    => 1,
);
sub _build_batch_id {
  my $self = shift;
  my $batch_id;
  # Cytoprofiling are not in production, so no batch_id for them
  if ( $self->run_type ne $RUN_CYTOPROFILE ) {
    ($batch_id) = $self->_run_params_data()->{$RUN_NAME} =~ /\AB?(\d+)/smx;
    if (!$batch_id) {
      $self->logcarp("Run parameter batch_id: wrong format in $RUN_PARAM_FILE");
    }
  }
  return $batch_id;
}

=head2 expected_cycle_count

The number of sequencing cycles that the instrument
is expected to complete. It is retrieved from
RunParameters.json file.

=cut
has q{expected_cycle_count}  => (
  isa               => q{Int},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
);
sub _build_expected_cycle_count {
  my $self = shift;
  my @exp_cycles;
  if ( $self->run_type eq $RUN_CYTOPROFILE ) {
    @exp_cycles =  map { $_->{$CYCLES} }
                   grep { $_->{'Type'} eq 'BarcodingBatch' }
                   @{$self->_run_params_data()->{'Batches'}};
  } else {
    @exp_cycles = values %{$self->_run_params_data()->{$CYCLES}};
  }
  return sum @exp_cycles;
}

=head2 actual_cycle_count

The number of sequencing cycles that the instrument
has currently completed.

=cut
has q{actual_cycle_count}  => (
  isa               => q{Int},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
);
sub _build_actual_cycle_count {
  my $self = shift;
 
  my $dir_name = 'BaseCalls';
  my $basecalls_dir = catdir $self->runfolder_path, $dir_name;
  if (!-d $basecalls_dir) {
    $basecalls_dir = catdir $self->runfolder_path, 'BaseCalling', $dir_name;
  }
 
  my @cycle_files = ();
  if (-d $basecalls_dir) {
    my $cycle_pattern = ($self->run_type eq $RUN_CYTOPROFILE) ?
      $CYCLE_FILE_PATTERN_CYTO : $CYCLE_FILE_PATTERN;
    my @files = glob catfile($basecalls_dir, '*.zip');
    foreach my $f ( @files ) {
      if (basename($f) =~ qr/$cycle_pattern/) {
        push @cycle_files, $f;
      }
    }
  } else {
    $self->warn("$dir_name not found");
  }

  return scalar @cycle_files;
}

#####
# Inspect the file system to retrieve the number of cycles
# that have been completed so far and update the DB if
# it is not up-to-date.
sub _set_actual_cycle_count {
  my ($self) = shift;

  my $tracking_run = $self->tracking_run();
  my $remote_cycle_count = $tracking_run->actual_cycle_count();
  my $actual_cycle_count = $self->actual_cycle_count;

  if (! defined $remote_cycle_count) {
    $tracking_run->update({actual_cycle_count => $actual_cycle_count});
    $self->info("Run parameter $CYCLES: actual cycle count initiated");
  } elsif ($actual_cycle_count < $remote_cycle_count) {
    $self->logcroak("Run parameter $CYCLES: cycle count inconsistency on file system");
  } elsif ($actual_cycle_count == $remote_cycle_count) {
    $self->info("Run parameter $CYCLES: nothing to update");
  } else {
    $tracking_run->update({actual_cycle_count => $actual_cycle_count});
    $self->info("Run parameter $CYCLES: actual cycle count updated");
  }
}

=head2 lane_count

The number of lanes that are used on one side.
It is retrieved from RunParameters.json file.

=cut
has q{lane_count}  => (
  isa               => q{Int},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
);
sub _build_lane_count {
  my $self = shift;
  my @lanes = split /\+/, $self->_run_params_data()->{$LANES};
  if (! @lanes) {
    $self->logcroak("Run parameter $LANES: No lane found");
  }
  return scalar @lanes;
}

=head2 date_created

The date when the run was created.
By default, it is retrieved from the RunParameters.json.
If not present in the file, the time stamp of the file is choosen.

=cut
has q{date_created} => (
  isa               => q{DateTime},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
);
sub _build_date_created {
  my $self = shift;
  my $file_path = catfile($self->runfolder_path, $RUN_PARAM_FILE);
  if (! exists $self->_run_params_data()->{$DATE} or ! $self->_run_params_data()->{$DATE}) {
    $self->logcarp("Run parameter $DATE: No value in $RUN_PARAM_FILE");
    return DateTime->from_epoch(epoch => (stat  $file_path)[9]);
  } else {
    my $date = $self->_run_params_data()->{$DATE};
    try {
      return DateTime::Format::Strptime->new(
        pattern=>$TIME_PATTERN,
        strict=>1,
        on_error=>q[croak]
      )->parse_datetime($date);
    } catch {
      $self->logcarp("Run parameter $DATE: failed to parse $date");
      return DateTime->from_epoch(epoch => (stat  $file_path)[9]);
    };
  }
}

=head2 is_paired

If paired run (the run has a reverse read) return 1, otherwise 0.

=cut
has q{is_paired} => (
  isa         => q{Bool},
  is          => q{ro},
  required    => 0,
  lazy_build  => 1,
);
sub _build_is_paired {
  my $self = shift;
  my $cycles = $self->_run_params_data()->{$CYCLES};
  if ( exists $cycles->{$CYCLES_R2} and int($cycles->{$CYCLES_R2}) > 0 ) {
    return 1;
  }
  return 0;
}

=head2 is_indexed

If the run has at least one index read return 1, otherwise 0.

=cut
has q{is_indexed} => (
  isa         => q{Bool},
  is          => q{ro},
  required    => 0,
  lazy_build  => 1,
);
sub _build_is_indexed {
  my $self = shift;
  my $cycles = $self->_run_params_data()->{$CYCLES};
  if ( exists $cycles->{$CYCLES_I1} and int($cycles->{$CYCLES_I1}) > 0 ) {
    return 1;
  }
  return 0;
}

sub _set_tags {
  my ($self) = shift;
  my @tags = (
    'staging'
  );
  if ($self->is_paired) {
    push @tags, 'paired_read';
  }
  if ($self->is_indexed) {
    push @tags, 'multiplex';
  }
  if ($self->run_type eq $RUN_CYTOPROFILE) {
    push @tags, lc($self->run_type);
  }

  foreach my $tag ( @tags ) {
    $self->tracking_run()->set_tag($USERNAME, $tag);
    $self->info("$tag tag is set");
  }
}

#####
# Hash reference that represents the JSON file content of RunParameters.json.
has q{_run_params_data} => (
  isa               => q{HashRef},
  is                => q{ro},
  required          => 0,
  init_arg          => undef,
  lazy_build        => 1,
);
sub _build__run_params_data {
  my $self = shift;
  my $run_parameters_file = catfile($self->runfolder_path, $RUN_PARAM_FILE);
  return decode_json(slurp $run_parameters_file);
}

=head2 is_failed

When the run finishes with failed outcome and it has not
completed the expected cycle number return 1, otherwise 0.

=cut
has q{is_failed}  => (
  isa               => q{Bool},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
);
sub _build_is_failed {
  my $self = shift;
  my $upload_data = $self->_run_uploaded_data();
  my $data_ok = defined $upload_data and exists $upload_data->{$OUTCOME};
  if ( $data_ok
        and $upload_data->{$OUTCOME} eq $OUTCOME_FAILED
        and $self->actual_cycle_count < $self->expected_cycle_count ) {
    return 1;
  }
  return 0;
}

=head2 is_completed

When the run has been successfully completed with the full
expected cycle number return 1, otherwise 0.

=cut
has q{is_completed}  => (
  isa               => q{Bool},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
);
sub _build_is_completed {
  my $self = shift;
  if ( $self->actual_cycle_count == $self->expected_cycle_count ) {
    return 1;
  }
  return 0;
}

#####
# Hash reference that represents the JSON file content of RunUploaded.json.
has q{_run_uploaded_data} => (
  isa               => q{Maybe[HashRef]},
  is                => q{ro},
  required          => 0,
  init_arg          => undef,
  lazy_build        => 1,
);
sub _build__run_uploaded_data {
  my $self = shift;
  my $run_uploaded_file = catfile($self->runfolder_path, $RUN_UPLOAD_FILE);
  my $json_data;
  if ( -e $run_uploaded_file ) {
    $json_data = decode_json(slurp $run_uploaded_file);
  }
  return $json_data;
}

=head2 run_type

Type of the run.

=cut
has q{run_type}     => (
  isa           => q{Str},
  is            => q{ro},
  required      => 0,
  lazy_build    => 1,
);
sub _build_run_type {
  my $self = shift;
  return $self->_run_params_data()->{$RUN_TYPE};
}

=head2 process_run_parameters

Core function of the class that is called on the run folder
periodically to update dynamic properties of a run in the DB.
If a run record does not exist, it is created.
The cycle count, tags and the following statuses are
checked/assigned accordingly:
- 'run in progress'   run basecalling is in progress
- 'run stopped early' run finished with failed outcome
- 'run complete'      run completed successfully
Each of the above events saves a time stamp in the DB.

When the run status is one of the following, the function
will return early:
- 'run cancelled' (set by the user via web interface)
- 'run stopped early'
- 'run complete' (or later)
In addition, 'run archived' is assigned when the current
status is on 'archival pending'.

=cut
sub process_run_parameters {
  my $self = shift;
  my $run_row = $self->tracking_run();
  my $current_run_status_obj = $run_row->current_run_status;
  my $run_uploaded_path = catfile($self->runfolder_path, $RUN_UPLOAD_FILE);
  
  if ( ! $current_run_status_obj ) {
    $run_row->set_instrument_side($self->instrument_side, $USERNAME);
    $current_run_status_obj = $run_row->update_run_status($RUN_STATUS_INPROGRESS, $USERNAME, $self->date_created);
    $self->info('New run ' . $self->runfolder_path . ' created');
    $self->_set_tags();
  }

  my $current_status_description = $run_row->current_run_status_description;
  $self->info("Current run status is '$current_status_description'");
  my $current_run_status_dict = $current_run_status_obj->run_status_dict;
  if ( any { $_ eq $current_status_description} ($RUN_STATUS_STOPPED, $RUN_STATUS_CANCELLED, $RUN_STATUS_COMPLETE) ) {
    return;
  }
  if ( $current_run_status_dict->compare_to_status_description($RUN_STATUS_COMPLETE) > 0 ) {
    if ( $current_status_description eq $RUN_STATUS_ARCHIVAL_PENDING ) {
      $run_row->update_run_status($RUN_STATUS_ARCHIVED, $USERNAME);
      $self->info("Run moved to status '$RUN_STATUS_ARCHIVED'");
    }
    return;
  }

  $self->_set_actual_cycle_count();
  
  if (defined $self->_run_uploaded_data()) {
    if ($self->is_failed) {
      if ( $current_run_status_dict->compare_to_status_description($RUN_STATUS_STOPPED) == -1 ) {
        my $date = DateTime->from_epoch(epoch => (stat  $run_uploaded_path)[9]);
        $run_row->update_run_status($RUN_STATUS_STOPPED, $USERNAME, $date);
        $self->info('Run ' . $self->runfolder_path . ' is failed');
      } else {
        $self->info('Run ' . $self->runfolder_path . ' was failed, current status ' . $current_run_status_obj->description);
      }
    } else {
      if ($self->is_completed) {
        if ( $current_run_status_dict->compare_to_status_description($RUN_STATUS_COMPLETE) == -1 ) {
          my $date = DateTime->from_epoch(epoch => (stat  $run_uploaded_path)[9]);
          $run_row->update_run_status($RUN_STATUS_COMPLETE, $USERNAME, $date);
          $self->info('Run ' . $self->runfolder_path . ' is now completed');
        } else {
          $self->info('Run ' . $self->runfolder_path . ' was completed, current status ' . $current_run_status_obj->description);
        }
      }
    }
  }
}

=head2 find_run_db_record

Find a run record in the tracking DB.
Return npg_tracking::Schema::Result::Run for the found
record or an undefind value if the record is not found.

=cut
sub find_run_db_record() {
  my $self = shift;
  my $rs = $self->npg_tracking_schema->resultset('Run');
  my $run_row = $rs->find_with_attributes(
    $self->folder_name,
    $self->flowcell_id,
    $self->instrument_name,
  );
  return $run_row;
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

=item JSON

=item File::Basename

=item File::Spec::Functions

=item DateTime

=item List::Util

=item DateTime::Format::Strptime

=item Perl6::Slurp

=item Try::Tiny

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
