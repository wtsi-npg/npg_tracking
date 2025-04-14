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

sub write_elembio_run_manifest {
  my ($topdir_path, $runfolder_name) = @_;
  my $runfolder_path = catdir($topdir_path, $runfolder_name);
  make_path($runfolder_path);
  my $runmanifest_file = catfile($runfolder_path, q[RunManifest.json]);
  open(my $fh_man, '>', $runmanifest_file) or die "Could not open file '$runmanifest_file' $!";
  close $fh_man;
}

sub write_elembio_run_params {
  my ($topdir_path, $runfolder_name, $instrument_name, $experiment_name, $flowcell_id, $side, $date) = @_;
  my $runfolder_path = catdir($topdir_path, $runfolder_name);
  make_path($runfolder_path);
  my $runparameters_file = catfile($runfolder_path, q[RunParameters.json]);
  open(my $fh_param, '>', $runparameters_file) or die "Could not open file '$runparameters_file' $!";
  print $fh_param <<"ENDJSON";
{
  "FileVersion": "5.0.0",
  "RunName": "$experiment_name",
  "RunType": "Sequencing",
  "RunDescription": "",
  "Side": "Side${side}",
  "FlowcellID": "$flowcell_id",
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
  "AnalysisLanes": "1+2",
  "LibraryType": "Linear",
  "Tags": null
}
ENDJSON
  close $fh_param;
}

sub make_run_folder {
  my ($topdir_path, $runfolder_name, $instrument_name, $experiment_name, $flowcell_id, $side, $date) = @_;
  write_elembio_run_params(
    $topdir_path,
    $runfolder_name,
    $instrument_name,
    $experiment_name,
    $flowcell_id,
    $side,
    $date);
  write_elembio_run_manifest(
    $topdir_path,
    $runfolder_name);
}

1;
