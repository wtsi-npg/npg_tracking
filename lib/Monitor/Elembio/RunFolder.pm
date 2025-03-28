package Monitor::Elembio::RunFolder;

use Moose;
use Carp;
use Readonly;
use JSON;
use Perl6::Slurp;
use DateTime
use DateTime::Format::Strptime

with qw[
        WTSI::DNAP::Utilities::Loggable
    ];

our $VERSION = '0';

Readonly::Scalar my $FLOWCELL_ID = 'FlowcellID';
Readonly::Scalar my $FOLDER_NAME = 'RunFolderName';
Readonly::Scalar my $INSTRUMENT_NAME = 'InstrumentName';
Readonly::Scalar my $SIDE = 'Side';

Readonly::Scalar my $CYCLES = 'Cycles';
Readonly::Scalar my $DATE = 'Date';

Readonly::Scalar my $USERNAME => 'pipeline';

Readonly::Scalar my $TIME_PATTERN => '%Y-%m-%dT%H:%M:%S.%fZ'; # 2023-12-19T13:31:17.461926614Z

has q{id_run}           => (
  isa           => q{NpgTrackingRunId},
  is            => q{ro},
  required      => 1,
  lazy_build    => 1,
  documentation => 'String identifier for a sequencing run',
);

has q{flowcell_id}      => (
  isa           => q{Str},
  is            => q{ro},
  required      => 1,
  lazy_build    => 1,
  documentation => 'Flowcell ID of a run',
);

has q{folder_name}      => (
  isa           => q{Str},
  is            => q{ro},
  required      => 1,
  lazy_build    => 1,
  documentation => 'Run folder name',
);

has q{instrument_id}      => (
  isa           => q{Int},
  is            => q{ro},
  required      => 1,
  lazy_build    => 1,
  documentation => 'ID of the instrument where a run is performed',
);

has q{side}      => (
  isa           => q{Str},
  is            => q{ro},
  required      => 1,
  lazy_build    => 1,
  documentation => 'Instrument side on which a run is performed',
);

has q{cycle_count}      => (
  isa           => q{Int},
  is            => q{ro},
  required      => 1,
  lazy_build    => 1,
  documentation => 'Current cycle count detected in the run folder',
);

has q{date_created}     => (
  isa           => q{Str},
  is            => q{ro},
  required      => 1,
  lazy_build    => 1,
  documentation => 'Date of creation for a run',
);

has q{dry_run}     => (
  isa           => q{Int},
  is            => q{ro},
  required      => 0,
  lazy_build    => 0,
  documentation => 'If true, no change is made to the Tracking DB',
);

sub _build_id_run {
    my ($self) = shift;

    my $id_run = join "_", $self->folder_name, $self->flowcell_id, $self->instrument_id;
    self->$id_run = $id_run;
}

sub _set_instrument_side {
    my ($self) = shift;
    my $side = $self->instrument_side;

    if (! $side) {
        $self->debug("Run parameter $SIDE not set by the run");
        return;
    }
    my $db_side = $self->tracking_run()->instrument_side || q[];
    if ($db_side eq $side) {
        $self->debug("Run parameter $SIDE: Nothing to update");
        return;
    }
    if (! $self->{dry_run}) {
        my $updated = $self->tracking_run()->set_instrument_side($side, $USERNAME);
        if (! $updated) {
            $self->logcarp("Set run parameter $SIDE: Tracking fail");
            return;
        }
    }

    my $mess_prefix = 'DryRun - ' if $self->{dry_run} else '';
    $self->debug($mess_prefix . "Run parameter $SIDE updated");
    return $side;
}

sub _set_cycle_count {
    my ($self) = shift;

    if (! defined $self->cycle_count) {
        $self->logcarp("Run parameter $CYCLES: latest cycle count not supplied");
        return 0;
    }
    my $actual_cycle = $self->tracking_run()->actual_cycle_count();
    $actual_cycle ||= 0;
    if ($self->cycle_count > $actual_cycle) {
        if (! $self->{dry_run}) {
            $self->tracking_run()->update({actual_cycle_count => $self->cycle_count});
        }
        my $mess_prefix = 'DryRun - ' if $self->{dry_run} else '';
        $self->info($mess_prefix . "Run parameter $CYCLES: latest cycle count updated");
        return 1;
    }
    $self->debug("Run parameter $CYCLES: Nothing to update");
    return 0;
}

sub update_remote_run_parameters {
    ($self, $dryrun) = @_;
    $self->_set_instrument_side();
    $self->_set_cycle_count();
}

sub _load_run_parameters {
    my ($self, $file_path) = @_;
    my $json_text = do {
        open(my $json_fh, "<:encoding(UTF-8)", $file_path)
            or $self->logcroak("Can't open \"$file_path\": $!\n");
        local $/;
        <$json_fh>
    };

    my $run_params = decode_json($json_text);
    $self->debug('Parsed RunParameters.json');

    foreach my $main_attr ($FLOWCELL_ID, $FOLDER_NAME, $INSTRUMENT_NAME, $SIDE) {
        if (! exists $run_params{$main_attr}) {
            $self->logcroak("Run parameter $main_attr: No value in RunParameters.json");
        }
    }
    $self->{flowcell_id} = $run_params->{$FLOWCELL_ID};
    $self->{folder_name} = $run_params->{$FOLDER_NAME};
    $self->{instrument_name} = $run_params->{$INSTRUMENT_NAME};
    my ($side) = $run_params->{$SIDE} =~ /Side(A|B)/smx;
    if (!$side) {
        $self->logcroak("Run parameter $SIDE: Failed to get it from RunParameters.json");
    }
    $self->{side} = $run_params->{$SIDE};

    if (! exists $run_params{$CYCLES}) {
        $self->logcarp("Run parameter $CYCLES: Failed to get it from RunParameters.json");
    } else {
        $self->{cycle_count} = sum values %{$cycles_info};
    }

    if (! exists $run_params{$DATE}) {
        $self->logcarp("Run parameter $DATE: No value in RunParameters.json");
        $self->{data_created} = DateTime->from_epoch(epoch => (stat  $file_path)[9])
                                        ->strftime($TIME_PATTERN);
    } else {
        my $date = $run_params->{$DATE}
        try {
            $date_obj = DateTime::Format::Strptime->new(
                pattern=>$TIME_PATTERN,
                strict=>1,
                on_error=>q[croak]
            )->parse_datetime($date);
            $self->{data_created} = $date
        } catch {
            $self->logcarp("Run parameter $DATE: failed to parse $date");
        };
    }
}
