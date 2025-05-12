package Monitor::Elembio::RunFolder;

use Moose;
use Carp;
use Readonly;
use JSON;
use File::Basename;
use File::Spec::Functions qw( catfile catdir );
use DateTime;
use List::Util 'sum';
use DateTime::Format::Strptime;
use Perl6::Slurp;
use Try::Tiny;
use File::Find;

use npg_tracking::Schema;
use Monitor::Elembio::Enum qw( 
  $BASECALL_FOLDER
  $CONSUMABLES
  $CYCLE_FILE_PATTERN
  $CYCLES
  $DATE
  $FLOWCELL
  $FOLDER_NAME
  $INSTRUMENT_NAME
  $INSTRUMENT_TABLE
  $LANES
  $RUN_TABLE
  $RUNLANE_TABLE
  $SERIAL_NUMBER
  $SIDE
  $TIME_PATTERN
  $USERNAME
);

with qw[
  WTSI::DNAP::Utilities::Loggable
];

our $VERSION = '0';

has q{runfolder_path} => (
  isa           => q{Str},
  is            => q{ro},
  required      => 1,
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
    $self->info('Created run ' . $run_row->folder_name . ' with ID ' . $run_row->id_run);

    my $tag = 'staging';
    $run_row->set_tag($USERNAME, $tag);
    $self->info("$tag tag is set");

    my $runlane_rs = $run_row->result_source()->schema()->resultset($RUNLANE_TABLE);
    for my $lane (1 .. $self->lane_count) {
      $runlane_rs->create({id_run => $run_row->id_run, position => $lane});
      $self->info("Created record for lane $lane of run_id " . $run_row->id_run);
    }
  }
  return $run_row;
}

has q{tracking_instrument} => (
  isa           => q{npg_tracking::Schema::Result::Instrument},
  is            => q{ro},
  lazy          => 1,
  builder       => q{_build_tracking_instrument},
);
sub _build_tracking_instrument {
  my $self = shift;
  my $rs = $self->npg_tracking_schema->resultset($INSTRUMENT_TABLE);
  my $params = {
    external_name => $self->instrument_name,
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
);
sub _build_flowcell_id {
  my $self = shift;
  my $flowcell_id = $self->_run_params_data()->{$CONSUMABLES}->{$FLOWCELL}->{$SERIAL_NUMBER};
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
);
sub _build_expected_cycle_count {
  my $self = shift;
  return sum values %{$self->_run_params_data()->{$CYCLES}};
}

has q{actual_cycle_count}  => (
  isa               => q{Int},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
);
sub _build_actual_cycle_count {
  my $self = shift;
  my @objfound = $self->_find_in_runfolder(qr/$BASECALL_FOLDER/);
  my $num_items = scalar @objfound;
  if ($num_items > 1) {
    $self->logcroak('too many items of ' . $BASECALL_FOLDER . ' found in ' . $self->runfolder_path);
  }
  my @cycle_files = ();
  if ($num_items == 1) {
    my @files = glob catfile($objfound[0], '*.zip');
    foreach my $f ( @files ) {
      if (basename($f) =~ qr/${CYCLE_FILE_PATTERN}/) {
        push @cycle_files, $f;
      }
    }
  }
  return scalar @cycle_files;
}

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

has q{lane_count}  => (
  isa               => q{Int},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
);
sub _build_lane_count {
  my $self = shift;
  my @lanes = split /\+/, $self->_run_params_data()->{$LANES};
  return scalar @lanes;
}

has q{date_created} => (
  isa               => q{Str},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
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
  $self->_set_actual_cycle_count();
  if ($is_run_complete) {
    $run_row->update_run_status('run complete', $USERNAME);
    $self->info('Run ' . $self->runfolder_path . ' completed');
  }
}

sub _find_in_runfolder() {
  my ($self, $objname) = @_;
  my @objfound = ();

  my $wanted = sub {
    if ( $_ =~ qr/${objname}$/) {
      push @objfound, $File::Find::name;
    }
  };
  my $find_args = {
    wanted => $wanted,
    follow => 0,
    no_chdir => 0
  };
  find($find_args, ( $self->runfolder_path ));

  return @objfound;
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

=head1 SUBROUTINES/METHODS

=head2 process_run_parameters

Inspect the file system or the progress of the run 
and update properties in the tracking database

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item Readonly

=item JSON

=item File::Basename

=item File::Spec::Functions qw( catfile catdir )

=item DateTime

=item List::Util 'sum'

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
