use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use File::Temp qw/ tempdir /;
use File::Spec::Functions qw( catdir );

use t::dbic_util;
use t::elembio_run_util qw( make_run_folder );

BEGIN {
  local $ENV{'HOME'} = 't';
  use_ok('Monitor::Elembio::Staging', 'find_run_folders');
}

my $schema = t::dbic_util->new->test_schema(fixture_path => q[t/data/dbic_fixtures]);

subtest 'test staging monitor find runs' => sub {
  plan tests => 3;

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
      {}, []
    );
  }
  throws_ok { find_run_folders() }
            qr/Top[ ]level[ ]staging[ ]path[ ]required/msx,
            'Require path argument';
  throws_ok { find_run_folders('/no/such/path') }
            qr/[ ]not[ ]a[ ]directory/msx, 'Require real path';
  is (scalar find_run_folders($testdir), 3, 'correct number of run folders found');
};

1;
