package Monitor::Elembio::RunFolder;

use Moose;
use Carp;
use Readonly;
use JSON;
use File::Basename;
use File::Spec::Functions 'catfile';
use DateTime;
use List::Util 'sum';
use DateTime::Format::Strptime;
use Perl6::Slurp;
use Try::Tiny;

use npg_tracking::Schema;

with qw[
  WTSI::DNAP::Utilities::Loggable
];

our $VERSION = '0';

Readonly::Scalar my $RUN_TABLE => 'Run';
Readonly::Scalar my $INSTRUMENT_TABLE => 'Instrument';
Readonly::Scalar my $FLOWCELL_ID => 'FlowcellID';
Readonly::Scalar my $FOLDER_NAME => 'RunFolderName';
Readonly::Scalar my $INSTRUMENT_NAME => 'InstrumentName';
Readonly::Scalar my $SIDE => 'Side';
Readonly::Scalar my $CYCLES => 'Cycles';
Readonly::Scalar my $DATE => 'Date';

Readonly::Scalar my $USERNAME => 'pipeline';

Readonly::Scalar my $TIME_PATTERN => '%Y-%m-%dT%H:%M:%S.%NZ'; # 2023-12-19T13:31:17.461926614Z

has q{runfolder_path} => (
  isa           => q{Str},
  is            => q{ro},
  required      => 1,
  documentation => 'Path to the run folder',
);

has q{npg_tracking_schema}  => (
  isa        => 'npg_tracking::Schema',
  is         => q{ro},
  required   => 1,
);

has q{tracking_run} => (
  isa           => q{npg_tracking::Schema::Result::Run},
  is            => q{ro},
  lazy          => 1,
  builder       => q{_build_tracking_run},
  documentation => 'NPG tracking DBIC object for a run',
);
sub _build_tracking_run {
  my $self = shift;
  my $rs = $self->npg_tracking_schema->resultset($RUN_TABLE);
  my $params = {
    flowcell_id   => $self->flowcell_id,
    folder_name   => $self->folder_name,
    id_instrument => $self->tracking_instrument()->id_instrument,
  };
  my @run_rows = $rs->search($params)->all();

  my $run_count = scalar @run_rows;
  if ($run_count > 1) {
    $self->logcroak('Multiple runs retrieved from NPG tracking DB');
  }
  my $run_row;
  if ($run_count == 1) {
    $run_row = $run_rows[0];
    $self->info('Found run ' . $run_row->folder_name . ' with ID ' . $run_row->id_run);
  } else {
    $self->info('will create a new run for ' . $self->runfolder_path);
    # We expect run name to start with batch_id (\A(\d+))
    # later we will assign the group to batch id
    my $data = {
      flowcell_id          => $self->flowcell_id,
      folder_name          => $self->folder_name,
      id_instrument        => $self->tracking_instrument()->id_instrument,
      folder_path_glob     => dirname($self->runfolder_path),
      expected_cycle_count => $self->expected_cycle_count,
      team                 => 'SR',
      id_instrument_format => $self->tracking_instrument()->id_instrument_format,
      priority             => 1,
      is_paired            => 1,
    };
    $run_row = $rs->create($data);
    # create lanes!!!!!
    $self->info('Created run ' . $run_row->folder_name . ' with ID ' . $run_row->id_run);
  }
  return $run_row;
}

has q{tracking_instrument} => (
  isa           => q{npg_tracking::Schema::Result::Instrument},
  is            => q{ro},
  lazy          => 1,
  builder       => q{_build_tracking_instrument},
  documentation => 'NPG tracking DBIC object for an instrument',
);
sub _build_tracking_instrument {
  my $self = shift;
  my $rs = $self->npg_tracking_schema->resultset($INSTRUMENT_TABLE);
  my $params = {
    name => $self->instrument_name,
    iscurrent => 1,
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

has q{flowcell_id}  => (
  isa             => q{Str},
  is              => q{ro},
  required        => 0,
  lazy_build      => 1,
  documentation   => 'Flowcell ID of a run',
);
sub _build_flowcell_id {
  my $self = shift;
  my $flowcell_id = $self->_run_params_data()->{$FLOWCELL_ID};
  if (! $flowcell_id) {
    $self->logcroak('Empty value in flowcell_id');
  }
  return $flowcell_id;
}

has q{folder_name}    => (
  isa               => q{Str},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
  documentation     => 'Run folder name',
);
sub _build_folder_name {
  my $self = shift;
  my $folder_name = $self->_run_params_data()->{$FOLDER_NAME};
  if (! $folder_name) {
    $self->logcroak('Empty value in folder_name');
  }
  return $folder_name;
}

has q{instrument_name}  => (
  isa               => q{Str},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
  documentation     => 'Run folder name',
);
sub _build_instrument_name {
  my $self = shift;
  return $self->_run_params_data()->{$INSTRUMENT_NAME};
}

has q{instrument_side}     => (
  isa           => q{Str},
  is            => q{ro},
  required      => 0,
  lazy_build    => 1,
  documentation => 'Instrument side on which a run is performed',
);
sub _build_instrument_side {
  my $self = shift;
  my ($side) = $self->_run_params_data()->{$SIDE} =~ /Side(A|B)/smx;
  if (!$side) {
    $self->logcroak("Run parameter $SIDE: wrong format in RunParameters.json");
  }
  return $side;
}

has q{expected_cycle_count}  => (
  isa               => q{Int},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
  documentation     => 'Expected cycle count detected in the run folder',
);
sub _build_expected_cycle_count {
  my $self = shift;
  return sum values %{$self->_run_params_data()->{$CYCLES}};
}

has q{date_created} => (
  isa               => q{Str},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
  documentation     => 'Date of creation for a run',
);
sub _build_date_created {
  my $self = shift;
  my $file_path = catfile($self->runfolder_path, 'RunParameters.json');
  if (! exists $self->_run_params_data()->{$DATE} or ! $self->_run_params_data()->{$DATE}) {
    $self->logcarp("Run parameter $DATE: No value in RunParameters.json");
    return DateTime->from_epoch(epoch => (stat  $file_path)[9])->strftime($TIME_PATTERN);
  } else {
    my $date = $self->_run_params_data()->{$DATE};
    try {
      DateTime::Format::Strptime->new(
        pattern=>$TIME_PATTERN,
        strict=>1,
        on_error=>q[croak]
      )->parse_datetime($date);
      return $date;
    } catch {
      $self->logcarp("Run parameter $DATE: failed to parse $date");
      return DateTime->from_epoch(epoch => (stat  $file_path)[9])->strftime($TIME_PATTERN);;
    };
  }
}

has q{_run_params_data} => (
  isa               => q{HashRef},
  is                => q{ro},
  required          => 0,
  init_arg          => undef,
  lazy_build        => 1,
);
sub _build__run_params_data {
  my $self = shift;
  my $run_parameters_file = catfile($self->runfolder_path, 'RunParameters.json');
  return decode_json(slurp $run_parameters_file);
}
sub _set_instrument_side {
  my ($self) = shift;
  my $side = $self->instrument_side;
  my $tracking_run = $self->tracking_run();
  my $db_side = $tracking_run->instrument_side || q[];
  if ($db_side eq $side) {
    $self->debug("Run parameter $SIDE: Nothing to update");
    return $side;
  }
  $tracking_run->set_instrument_side($side, $USERNAME);
  $self->info("Run parameter $SIDE updated with $side");
  return $side;
}

sub process_run_parameters {
  my $self = shift;
  my $run_row = $self->tracking_run();
  my $is_new_run = $run_row->current_run_status ? 0 : 1;
  my $is_run_complete = ( -e catfile($self->runfolder_path, 'RunUploaded.json') );
  if ($is_new_run) {
    $run_row->set_instrument_side($self->instrument_side, $USERNAME);
    $run_row->update_run_status('run in progress', $USERNAME);
    $self->info('New run ' . $self->runfolder_path . ' updated');
  }
  if ($is_run_complete) {
    $run_row->update_run_status('run complete', $USERNAME);
    $self->info('Run ' . $self->runfolder_path . ' completed');
  }
}

1;

__END__

=head1 NAME

Monitor::Elembio::RunFolder

=head1 VERSION

=head1 SYNOPSIS

    C<<use Monitor::Elembio::RunFolder;
       my $run_folder = Monitor::Elembio::runfolder->new();>>

=head1 DESCRIPTION

Properties loader for an Elembio run folder.
