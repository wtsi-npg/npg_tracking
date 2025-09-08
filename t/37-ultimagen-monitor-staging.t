use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use File::Copy::Recursive qw( dircopy );
use File::Temp qw/ tempdir /;
use File::Spec::Functions qw( catdir );

use t::dbic_util;

BEGIN {
  local $ENV{'HOME'} = 't';
  use_ok('Monitor::Ultimagen::Staging', 'find_run_folders');
}

subtest 'test ultimagen staging monitor find_run_folders' => sub {
  plan tests => 3;

  my $testdir = tempdir( CLEANUP => 1 );
  my $allruns_folder = 'Runs';
  my $data_folder = catdir('t/data/ultimagen_staging', $allruns_folder);
  my $test_allruns_folder = catdir($testdir, $allruns_folder);
  dircopy($data_folder, $test_allruns_folder) or die "cannot copy test directory $!";
  throws_ok { find_run_folders() }
            qr/Top[ ]level[ ]staging[ ]path[ ]required/msx,
            'Require path argument';
  throws_ok { find_run_folders('/no/such/path') }
            qr/[ ]not[ ]a[ ]directory/msx, 'Require real path';
  is (scalar find_run_folders($testdir), 2, 'run folders found');
};

1;
