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
  $RUN_CYTOPROFILE
  $RUN_STANDARD
  $RUN_STATUS_INPROGRESS
  $RUN_STATUS_TYPE
  $RUN_TYPE
  $RUN_UPLOAD_FILE
);
use Exporter;

our @ISA= qw( Exporter );
our @EXPORT = qw( make_run_folder update_run_folder );

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

sub update_run_folder {
  my ($runfolder_path, $test_params) = @_;
  my $basecalls_path;
  if ($test_params->{$RUN_TYPE} eq $RUN_CYTOPROFILE) {
    $basecalls_path = catdir($runfolder_path, 'BaseCalling', $BASECALL_FOLDER);
  } elsif ($test_params->{$RUN_TYPE} eq $RUN_STANDARD) {
    $basecalls_path = catdir($runfolder_path, $BASECALL_FOLDER);
  }
  make_path($basecalls_path);
  if (exists $test_params->{$CYCLES}) {
    write_cycle_files($test_params->{$CYCLES}, $basecalls_path);
  }
  if ($test_params->{$RUN_STATUS_TYPE} eq $RUN_STATUS_INPROGRESS) {
    unlink(catfile($runfolder_path, $RUN_UPLOAD_FILE));
  }
}

1;
