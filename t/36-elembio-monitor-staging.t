use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use File::Copy::Recursive qw( dircopy );
use File::Temp qw/ tempdir /;
use File::Spec::Functions qw( catdir );

use t::dbic_util;
use t::elembio_util qw( make_run_folder );

BEGIN {
  local $ENV{'HOME'} = 't';
  use_ok('Monitor::Elembio::Staging', 'find_run_folders');
}

my $schema = t::dbic_util->new->test_schema(fixture_path => q[t/data/dbic_fixtures]);

subtest 'test staging monitor find runs' => sub {
  plan tests => 3;

  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_folder = 'AV244103';
  my $data_folder = catdir('t/data/elembio_staging', $instrument_folder);
  my $test_instr_folder = catdir($testdir, $instrument_folder);
  dircopy($data_folder, $test_instr_folder) or die "cannot copy test directory $!";
  throws_ok { find_run_folders() }
            qr/Top[ ]level[ ]staging[ ]path[ ]required/msx,
            'Require path argument';
  throws_ok { find_run_folders('/no/such/path') }
            qr/[ ]not[ ]a[ ]directory/msx, 'Require real path';
  is (scalar find_run_folders($testdir), 3, 'sequencing run folder found, cytoprofiling skipped');
};

1;
