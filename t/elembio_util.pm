package t::elembio_util;

use strict;
use warnings;
use Carp;
use DateTime;
use Readonly;
use File::Path qw/ make_path /;
use File::Spec::Functions qw( catfile catdir );
use Monitor::Elembio::Enum qw( 
  $CYCLES
  $RUN_STATUS_TYPE
  $RUN_TYPE
);
use Exporter;

our @ISA= qw( Exporter );
our @EXPORT = qw( update_run_folder );

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
  if ($test_params->{$RUN_TYPE} eq 'Cytoprofiling') {
    $basecalls_path = catdir($runfolder_path, 'BaseCalling', 'BaseCalls');
  } elsif ($test_params->{$RUN_TYPE} eq 'Sequencing') {
    $basecalls_path = catdir($runfolder_path, 'BaseCalls');
  }
  make_path($basecalls_path);
  if (exists $test_params->{$CYCLES}) {
    write_cycle_files($test_params->{$CYCLES}, $basecalls_path);
  }
  if ($test_params->{$RUN_STATUS_TYPE} eq 'run in progress') {
    unlink(catfile($runfolder_path, 'RunUploaded.json'));
  }
}

1;
