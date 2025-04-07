package Monitor::Elembio::RunFolder;

use Moose;
use Carp;
use Readonly;
use JSON;
use Perl6::Slurp;
use File::Spec::Functions 'catfile';
use DateTime
use DateTime::Format::Strptime
use npg_tracking::Schema

with qw[
        WTSI::DNAP::Utilities::Loggable
    ];

our $VERSION = '0';

Readonly::Scalar my $TABLE = 'ESeqRun';
Readonly::Scalar my $FLOWCELL_ID = 'FlowcellID';
Readonly::Scalar my $FOLDER_NAME = 'RunFolderName';
Readonly::Scalar my $INSTRUMENT_NAME = 'InstrumentName';
Readonly::Scalar my $SIDE = 'Side';

Readonly::Scalar my $CYCLES = 'Cycles';
Readonly::Scalar my $DATE = 'Date';

Readonly::Scalar my $USERNAME => 'pipeline';

Readonly::Scalar my $TIME_PATTERN => '%Y-%m-%dT%H:%M:%S.%fZ'; # 2023-12-19T13:31:17.461926614Z

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
    isa => q{npg_tracking::Schema::Result::Run},
    is => q{ro},
    lazy => 1,
    builder => q{_build_tracking_run},
    documentation => 'NPG tracking DBIC object for a run',
);
sub _build_tracking_run {
    my $self = shift;
    if ( ! $self->npg_tracking_schema ) {
        $self->logcroak('Need NPG tracking schema to get a run object from it');
    }
    my @run_rows = $self->npg_tracking_schema->resultset($TABLE)->search(
        {
            flowcell_id => $self->{flowcell_id},
            folder_name => $self->{folder_name},
        })->all();
    my $run_count = scalar @run_rows
    if ($run_count > 1) {
        $self->logcarp('Multiple runs retrieved from NPG tracking DB');
        return;
    } elsif ($run_count == 0) {
        $self->logcarp('No run found in NPG tracking DB');
        return;
    }
    return $run_rows[0]
}

has q{dry_run}  => (
  isa           => q{Int},
  is            => q{ro},
  required      => 1,
  documentation => 'If true, no change is made to the Tracking DB',
);

has q{id_run}   => (
  isa           => q{NpgTrackingRunId},
  is            => q{ro},
  required      => 0,
  documentation => 'String identifier for a sequencing run',
);

has q{flowcell_id}  => (
    isa             => q{Str},
    is              => q{ro},
    required        => 0,
    documentation   => 'Flowcell ID of a run',
);

has q{folder_name}  => (
  isa               => q{Str},
  is                => q{ro},
  required          => 0,
  documentation     => 'Run folder name',
);

has q{instrument_id}    => (
  isa                   => q{Int},
  is                    => q{ro},
  required              => 0,
  documentation         => 'ID of the instrument where a run is performed',
);

has q{side}     => (
  isa           => q{Str},
  is            => q{ro},
  required      => 0,
  documentation => 'Instrument side on which a run is performed',
);

has q{cycle_count}  => (
  isa               => q{Int},
  is                => q{ro},
  required          => 0,
  documentation     => 'Current cycle count detected in the run folder',
);

has q{date_created} => (
  isa               => q{Str},
  is                => q{ro},
  required          => 0,
  documentation     => 'Date of creation for a run',
);

sub get_run_parameter_file {
    ($runfolder) = @_;
    my $run_parameters_file = catfile($runfolder, 'RunParameters.json')
    if (! -e $run_parameters_file) {
        $self->logcarp("No RunParameters.json file in $run_dir") 
        return;
    }
    return $run_parameters_file;
}

sub new  
{ 
    my ($class, $args) = @_;
    my $self = { 
        runfolder_path => $args->{runfolder_path},
        schema => $args->{schema},
        dry_run => $args->{dry_run},
    };
    bless $self, $class;
    $run_parameters_file = get_run_parameter_file($self->{runfolder_path})
    if (! $run_parameters_file) {
        return;
    }
    if (! $self->_load_run_parameters($run_parameters_file)) {
        return;
    }
    return $self; 
} 


sub _set_instrument_side {
    my ($self) = shift;
    my $side = $self->instrument_side;

    if (! $side) {
        $self->debug("Run parameter $SIDE not set by the run");
        return;
    }
    my $tracking_run = $self->tracking_run();
    if (! $tracking_run) {
        return;
    }
    my $db_side = $tracking_run->instrument_side || q[];
    if ($db_side eq $side) {
        $self->debug("Run parameter $SIDE: Nothing to update");
        return $side;
    }
    if (! $self->{dry_run}) {
        my $updated = $tracking_run->set_instrument_side($side, $USERNAME);
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
    my $tracking_run = $self->tracking_run();
    if (! $tracking_run) {
        return 0;
    }
    my $actual_cycle = $tracking_run->actual_cycle_count();
    $actual_cycle ||= 0;
    if ($self->cycle_count > $actual_cycle) {
        if (! $self->{dry_run}) {
            $tracking_run->update({actual_cycle_count => $self->cycle_count});
        }
        my $mess_prefix = 'DryRun - ' if $self->{dry_run} else '';
        $self->info($mess_prefix . "Run parameter $CYCLES: latest cycle count updated");
        return 1;
    }
    $self->debug("Run parameter $CYCLES: Nothing to update");
    return 0;
}

sub update_remote_run_parameters {
    $self = shift;
    if ( ! $self->_set_instrument_side() or ! $self->_set_cycle_count()) {
        return 0;
    }
    return 1;
}

sub _load_run_parameters {
    my ($self, $file_path) = @_;
    my $json_text = do {
        open(my $json_fh, "<:encoding(UTF-8)", $file_path);
        if (! $json_fh) {
            $self->logcarp("Can't open \"$file_path\": $!\n");
            return 0;
        }
        local $/;
        <$json_fh>
    };

    my $run_params = decode_json($json_text);
    $self->debug('Parsed RunParameters.json');

    foreach my $main_attr ($FLOWCELL_ID, $FOLDER_NAME, $INSTRUMENT_NAME, $SIDE) {
        if (! exists $run_params{$main_attr}) {
            $self->logcarp("Run parameter $main_attr: No key in RunParameters.json");
            return 0;
        }
        if (! $run_params->{$main_attr}) {
            $self->logcarp("Run parameter $main_attr: Empty value in RunParameters.json");
            return 0;
        }
    }
    $self->{flowcell_id} = $run_params->{$FLOWCELL_ID};
    $self->{folder_name} = $run_params->{$FOLDER_NAME};
    $self->{instrument_name} = $run_params->{$INSTRUMENT_NAME};
    my ($side) = $run_params->{$SIDE} =~ /Side(A|B)/smx;
    if (!$side) {
        $self->logcarp("Run parameter $SIDE: wrong format in RunParameters.json");
        return 0;
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
    return 1;
}
