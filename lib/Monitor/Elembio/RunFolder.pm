package Monitor::Elembio::RunFolder;

use Moose;
use Carp;
use Readonly;
use JSON;
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
    id_instrument => $self->id_instrument,
  };
  my @run_rows = $rs->search($params)->all();

  my $run_count = scalar @run_rows;
  if ($run_count > 1) {
    $self->logcroak('Multiple runs retrieved from NPG tracking DB');
  }
  my $run_row;
  if ($run_count == 1) {
    $run_row = $run_rows[0];
    $self->info('Found run ' . $run_row->folder_name);
  } else {
    $self->logcarp('No run found in NPG tracking DB');
    my $data = {
      flowcell_id          => $self->flowcell_id,
      folder_name          => $self->folder_name,
      id_instrument        => $self->id_instrument,
      actual_cycle_count   => $self->cycle_count,
      team                 => 'RAD',
      id_instrument_format => 19,
    };
    $run_row = $rs->create($data);
    $run_row->set_instrument_side($self->instrument_side, $USERNAME);
    # assign status
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
    $self->logcroak('No instrument found in NPG tracking DB with name ' . $self->instrument_name);
  }

  my $instrument_row = $instrument_rows[0];
  $self->debug('Found instrument ' . $instrument_row->name());  
  return $instrument_row;
}

has q{dry_run}  => (
  isa           => q{Int},
  is            => q{ro},
  required      => 0,
  init_arg      => 0,
  documentation => 'If true, no change is made to the Tracking DB',
);

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

has q{id_instrument}    => (
  isa               => q{Int},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
  documentation     => 'Instrument ID',
);
sub _build_id_instrument {
  my $self = shift;
  return $self->tracking_instrument()->id_instrument;
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

has q{cycle_count}  => (
  isa               => q{Int},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
  documentation     => 'Current cycle count detected in the run folder',
);
sub _build_cycle_count {
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
  if (! $self->dry_run) {
    $tracking_run->set_instrument_side($side, $USERNAME);
  }

  my $mess_prefix = '';
  if ($self->dry_run) {$mess_prefix = 'DryRun - '};
  $self->debug($mess_prefix . "Run parameter $SIDE updated");
  return $side;
}

sub _set_cycle_count {
  my ($self) = shift;

  if (! defined $self->cycle_count) {
    $self->logcroak("Run parameter $CYCLES: latest cycle count not supplied");
  }
  my $tracking_run = $self->tracking_run();
  my $remote_cycle_count = $tracking_run->actual_cycle_count();
  $remote_cycle_count ||= 0;
  if ($self->cycle_count < $remote_cycle_count) {
    $self->logcroak("Run parameter $CYCLES: cycle count inconsistency on file system");
  } elsif ($self->cycle_count == $remote_cycle_count) {
    $self->debug("Run parameter $CYCLES: Nothing to update");
    return;
  }

  if (! $self->dry_run) {
    $tracking_run->update({actual_cycle_count => $self->cycle_count});
  }
  my $mess_prefix = '';
  if ($self->dry_run) {$mess_prefix = 'DryRun - '};
  $self->info($mess_prefix . "Run parameter $CYCLES: latest cycle count updated");
}

sub update_remote_run_parameters {
  my $self = shift;
  $self->_set_cycle_count();
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
