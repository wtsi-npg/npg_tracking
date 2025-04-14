use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use File::Temp qw/ tempdir /;
use File::Spec::Functions qw( catdir );

use t::dbic_util;
use t::elembio_run_util qw( make_run_folder );

BEGIN {
  local $ENV{'HOME'} = 't';
  use_ok('Monitor::Elembio::Staging');
}

my $schema = t::dbic_util->new->test_schema(fixture_path => q[t/data/dbic_fixtures]);

subtest 'test staging monitor find runs' => sub {
  plan tests => 4;

  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_name = q[AV244103];
  foreach my $experiment_name (qw(NT1234567B NT1234567C NT1234567D)) {
    my $runfolder_name = qq[20250325_${instrument_name}_${experiment_name}];
    make_run_folder(
      $testdir,
      $runfolder_name,
      $instrument_name,
      $experiment_name,
      q[], q[], q[],
    );
  }
  my $test;
  lives_ok { $test = Monitor::Elembio::Staging->new( npg_tracking_schema => $schema ) }
        'Object creation ok';
  throws_ok { $test->find_run_folders() }
            qr/Top[ ]level[ ]staging[ ]path[ ]required/msx,
            'Require path argument';
  throws_ok { $test->find_run_folders('/no/such/path') }
            qr/[ ]not[ ]a[ ]directory/msx, 'Require real path';
  is (scalar $test->find_run_folders($testdir), 3, 'correct number of run folders found');
};

subtest 'test staging monitor run status' => sub {
  plan tests => 1;

  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_name = q[AV244103];
  my $flowcell_id = q[1234567890];
  my $experiment_name = q[NT1234567B];
  my $side = 'A';
  my $date = '2025-01-01T12:00:59.792171889Z';
  my $runfolder_name = qq[20250411_${instrument_name}_${experiment_name}];
  my $runfolder_path = catdir($testdir, $instrument_name, $runfolder_name);
  make_run_folder(
    $testdir,
    $runfolder_name,
    $instrument_name,
    $experiment_name,
    $flowcell_id,
    $side,
    $date,
  );
  my $test = Monitor::Elembio::Staging->new( npg_tracking_schema => $schema );
  lives_ok { $test->monitor_run_status($runfolder_path, 0); } 'run folder monitor returns correctly';

};

1;
