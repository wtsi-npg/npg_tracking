package t::elembio_run_util;

use strict;
use warnings;
use Carp;
use DateTime;
use Readonly;
use File::Path qw/ make_path /;
use File::Spec::Functions qw( catfile catdir );
use Exporter;

our @ISA= qw( Exporter );
our @EXPORT = qw( write_elembio_run_manifest write_elembio_run_params make_run_folder );

Readonly::Scalar our $ENUM_CYTOPROFILE => 'Cytoprofiling';
Readonly::Scalar our $ENUM_STANDARD => 'Standard';

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
  my ($topdir_path, $runfolder_name, $instrument_name, $experiment_name, $flowcell_id, $side, $date, $cycles, $lanes, $type) = @_;
  my $runfolder_path = catdir($topdir_path, $instrument_name, $runfolder_name);
  my $basecalls_path;
  if ($type eq $ENUM_CYTOPROFILE) {
    $basecalls_path = catdir($runfolder_path, 'BaseCalling', 'BaseCalls');
  } elsif ($type eq $ENUM_STANDARD) {
    $basecalls_path = catdir($runfolder_path, 'BaseCalls');
  }
  make_path($runfolder_path);
  write_elembio_run_params(
    $topdir_path,
    $runfolder_name,
    $instrument_name,
    $experiment_name,
    $flowcell_id,
    $side,
    $date,
    $lanes);
  write_elembio_run_manifest(
    $topdir_path,
    $runfolder_name,
    $instrument_name);
  make_path($basecalls_path);
  write_cycle_files($cycles, $basecalls_path);
}

1;
