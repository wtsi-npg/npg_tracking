package t::elembio_util;

use strict;
use warnings;
use Carp;
use DateTime;
use Readonly;
use File::Path qw/ make_path /;
use File::Spec::Functions qw( catfile catdir );
use Monitor::Elembio::Enum qw( 
	$BASECALL_FOLDER
	$CYCLES
	$DATE
	$FLOWCELL
	$FOLDER_NAME
	$INSTRUMENT_NAME
	$LANES
  $RUN_CYTOPROFILE
  $RUN_NAME
  $RUN_STANDARD
  $RUN_TYPE
	$SIDE
);
use Exporter;

our @ISA= qw( Exporter );
our @EXPORT = qw( make_run_folder );

sub write_cycle_files {
  my ($ir_counts, $basecalls_path) = @_;
  foreach my $read_type ( keys %{$ir_counts}) {
    foreach my $cycle (1 .. $ir_counts->{$read_type}) {
      my $cycle_file_name = $read_type . sprintf("_C%03d", $cycle) . '.zip';
      open(my $fh_cycle, '>', catfile($basecalls_path, $cycle_file_name))
        or die "Could not create file '$cycle_file_name' $!";
      close $fh_cycle;
    }
  }
}

sub write_elembio_run_manifest {
  my ($topdir_path, $runfolder_name, $instrument_name) = @_;
  my $runfolder_path = catdir($topdir_path, $instrument_name, $runfolder_name);
  my $runmanifest_file = catfile($runfolder_path, q[RunManifest.json]);
  open(my $fh_man, '>', $runmanifest_file) or die "Could not open file '$runmanifest_file' $!";
  close $fh_man;
}

sub write_elembio_run_params {
  my ($topdir_path, $runfolder_name, $instrument_name, $experiment_name, $flowcell_id, $side, $date, $lanes) = @_;
  my $runfolder_path = catdir($topdir_path, $instrument_name, $runfolder_name);
  my $runparameters_file = catfile($runfolder_path, q[RunParameters.json]);
  open(my $fh_param, '>', $runparameters_file) or die "Could not open file '$runparameters_file' $!";
  my $lanes_val = join q[+], @{$lanes};
  
  print $fh_param <<"ENDJSON";
{
  "FileVersion": "5.0.0",
  "RunName": "$experiment_name",
  "RunType": "Sequencing",
  "RunDescription": "",
  "Side": "Side${side}",
  "Date": "$date",
  "InstrumentName": "$instrument_name",
  "RunFolderName": "$runfolder_name",
  "Cycles": {
    "R1": 151,
    "R2": 151,
    "I1": 8,
    "I2": 8
  },
  "ReadOrder": "I1,I2,R1,R2",
  "PlatformVersion": "3.2.0",
  "AnalysisLanes": "$lanes_val",
  "LibraryType": "Linear",
  "Tags": null,
  "Consumables": {
    "Flowcell": {
      "SerialNumber": "$flowcell_id"
    }
  }
}
ENDJSON
  close $fh_param;
}

sub make_run_folder {
  my ($topdir_path, $test_params) = @_;
  my $runfolder_path = catdir($topdir_path, $test_params->{$INSTRUMENT_NAME}, $test_params->{$FOLDER_NAME});
  my $basecalls_path;
  if ($test_params->{$RUN_TYPE} eq $RUN_CYTOPROFILE) {
    $basecalls_path = catdir($runfolder_path, 'BaseCalling', $BASECALL_FOLDER);
  } elsif ($test_params->{$RUN_TYPE} eq $RUN_STANDARD) {
    $basecalls_path = catdir($runfolder_path, $BASECALL_FOLDER);
  }
  make_path($runfolder_path);
  write_elembio_run_params(
    $topdir_path,
    $test_params->{$FOLDER_NAME},
    $test_params->{$INSTRUMENT_NAME},
    $test_params->{$RUN_NAME},
    $test_params->{$FLOWCELL},
    $test_params->{$SIDE},
    $test_params->{$DATE},
    $test_params->{$LANES}
  );
  write_elembio_run_manifest(
    $topdir_path,
    $test_params->{$FOLDER_NAME},
    $test_params->{$INSTRUMENT_NAME}
  );
  make_path($basecalls_path);
  write_cycle_files($test_params->{$CYCLES}, $basecalls_path);
}

1;
