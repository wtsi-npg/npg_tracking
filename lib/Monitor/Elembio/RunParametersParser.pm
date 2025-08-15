package Monitor::Elembio::RunParametersParser;

use Moose;
use Carp;
use Readonly;
use JSON;
use File::Spec::Functions qw( catfile );
use DateTime;
use List::Util qw( sum );
use DateTime::Format::Strptime;
use Perl6::Slurp;
use Try::Tiny;

use npg_tracking::util::types;

our $VERSION = '0';

# Property Enums
Readonly::Scalar my $CONSUMABLES => 'Consumables';
Readonly::Scalar my $CYCLES => 'Cycles';
Readonly::Scalar my $CYCLES_I1 => 'I1';
Readonly::Scalar my $CYCLES_R2 => 'R2';
Readonly::Scalar my $DATE => 'Date';
Readonly::Scalar my $FLOWCELL => 'Flowcell';
Readonly::Scalar my $FOLDER_NAME => 'RunFolderName';
Readonly::Scalar my $INSTRUMENT_NAME => 'InstrumentName';
Readonly::Scalar my $LANES => 'AnalysisLanes';
Readonly::Scalar my $RUN_NAME => 'RunName';
Readonly::Scalar my $SERIAL_NUMBER => 'SerialNumber';
Readonly::Scalar my $SIDE => 'Side';
Readonly::Scalar my $TIME_PATTERN => '%Y-%m-%dT%H:%M:%S.%NZ'; # 2023-12-19T13:31:17.461926614Z

# Run Enums
Readonly::Scalar my $RUN_CYTOPROFILE => 'Cytoprofiling';
Readonly::Scalar my $RUN_PARAM_FILE => 'RunParameters.json';
Readonly::Scalar my $RUN_TYPE => 'RunType';

=head1 NAME

Monitor::Elembio::RunParametersParser

=head1 VERSION

=head1 SYNOPSIS

C<<use Monitor::Elembio::RunParametersParser;
   my $run_folder = Monitor::Elembio::RunParametersParser->new(
     runfolder_path      => $run_folder);>>

=head1 DESCRIPTION

Elembio parser for RunParameters.json file

=head1 SUBROUTINES/METHODS

=head2 BUILD

An extension for the constructor method. Checks that either
runfolder_path or runparams_path options are specified.

=cut

sub BUILD {
  my $self = shift;
  $self->has_runfolder_path || $self->has_runparams_path
    || croak 'runfolder_path or runparams_path must be specified';
}

=head2 runfolder_path

Path of the run folder.

=cut
has q{runfolder_path} => (
  isa           => q{Str},
  is            => q{ro},
  predicate     => q{has_runfolder_path},
  required      => 0,
);

=head2 runparams_path

Path of the RunParameters.json file.

=cut
has q{runparams_path} => (
  isa           => q{Str},
  is            => q{ro},
  predicate     => q{has_runparams_path},
  required      => 0,
);

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
  my $flowcell_id = $self->_run_params_data()
    ->{$CONSUMABLES}->{$FLOWCELL}->{$SERIAL_NUMBER};
  if (! $flowcell_id) {
    croak 'Empty value in flowcell_id';
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
    croak 'Empty value in folder_name';
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
    croak "Run parameter $SIDE: wrong format in $RUN_PARAM_FILE";
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
  if ( $self->run_type && ($self->run_type ne $RUN_CYTOPROFILE) ) {
    ($batch_id) = $self->_run_params_data()->{$RUN_NAME} =~ /\AB?(\d+)/smx;
    if (!$batch_id) {
      carp "Run parameter batch_id: wrong format in $RUN_PARAM_FILE";
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
  if ( $self->run_type && ($self->run_type eq $RUN_CYTOPROFILE) ) {
    @exp_cycles =  map { $_->{$CYCLES} }
                   grep { $_->{'Type'} eq 'BarcodingBatch' }
                   @{$self->_run_params_data()->{'Batches'}};
  } else {
    @exp_cycles = values %{$self->_run_params_data()->{$CYCLES}};
  }
  return sum @exp_cycles;
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
    croak "Run parameter $LANES: No lane found";
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
    carp "Run parameter $DATE: No value in $RUN_PARAM_FILE";
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
      carp "Run parameter $DATE: failed to parse $date";
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

=head2 run_type

Type of the run.

=cut
has q{run_type}     => (
  isa           => q{Maybe[Str]},
  is            => q{ro},
  required      => 0,
  lazy_build    => 1,
);
sub _build_run_type {
  my $self = shift;
  return $self->_run_params_data()->{$RUN_TYPE};
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

=item File::Spec::Functions

=item DateTime

=item List::Util

=item DateTime::Format::Strptime

=item Perl6::Slurp

=item Try::Tiny

=item npg_tracking::util::types

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
