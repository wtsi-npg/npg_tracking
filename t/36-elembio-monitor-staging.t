use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use File::Temp qw/ tempdir /;
use File::Spec::Functions qw( catdir );

use t::dbic_util;
use t::elembio_util qw( make_run_folder );
use Monitor::Elembio::Enum qw( 
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

BEGIN {
  local $ENV{'HOME'} = 't';
  use_ok('Monitor::Elembio::Staging', 'find_run_folders');
}

my $schema = t::dbic_util->new->test_schema(fixture_path => q[t/data/dbic_fixtures]);

subtest 'test staging monitor find runs' => sub {
  plan tests => 3;

  my $testdir = tempdir( CLEANUP => 1 );
  foreach my $run_name (qw(NT1234567B NT1234567C NT1234567D)) {
    my $test_params = {
      $INSTRUMENT_NAME => q[AV244103],
      $FLOWCELL => q[],
      $RUN_NAME => $run_name,
      $SIDE => q[],
      $DATE => q[],
      $CYCLES => {},
      $LANES => [],
      $FOLDER_NAME => qq[20250411_AV244103_$run_name],
      $RUN_TYPE => $RUN_STANDARD
    };
    make_run_folder(
      $testdir,
      $test_params
    );
  }
  throws_ok { find_run_folders() }
            qr/Top[ ]level[ ]staging[ ]path[ ]required/msx,
            'Require path argument';
  throws_ok { find_run_folders('/no/such/path') }
            qr/[ ]not[ ]a[ ]directory/msx, 'Require real path';
  is (scalar find_run_folders($testdir), 3, 'correct number of run folders found');
};

subtest 'cytoprofiling run folders' => sub {
  plan tests => 1;

  my $testdir = tempdir( CLEANUP => 1 );
  foreach my $run_name (qw(NT1234567B NT1234567C NT1234567D)) {
    my $test_params = {
      $INSTRUMENT_NAME => q[AV244103],
      $FLOWCELL => q[],
      $RUN_NAME => $run_name,
      $SIDE => q[],
      $DATE => q[],
      $CYCLES => {},
      $LANES => [],
      $FOLDER_NAME => qq[20250411_AV244103_$run_name],
      $RUN_TYPE => $RUN_CYTOPROFILE
    };
    make_run_folder(
      $testdir,
      $test_params
    );
  }
  is (scalar find_run_folders($testdir), 0, 'correct number of cytoprofile run folders');
};

1;
