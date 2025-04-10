use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use File::Temp qw/ tempdir /;
use File::Path qw/ make_path /;
use File::Spec::Functions qw( catfile catdir );

use t::dbic_util;

BEGIN {
  local $ENV{'HOME'} = 't';
  use_ok('Monitor::Elembio::Staging');
}

my $schema = t::dbic_util->new->test_schema(fixture_path => q[t/data/dbic_fixtures]);

sub make_run_folder {
  my $runfolder_path = shift;
  make_path($runfolder_path);
  my $runmanifest_file = catfile($runfolder_path, q[RunManifest.json]);
  my $runparameters_file = catfile($runfolder_path, q[RunParameters.json]);
  open(my $fh_p, '>', $runmanifest_file) or die "Could not open file '$runmanifest_file' $!";
  open(my $fh_m, '>', $runparameters_file) or die "Could not open file '$runparameters_file' $!";
  close $fh_p;
  close $fh_m;
}

subtest 'test staging monitor find runs' => sub {
  plan tests => 4;

  my $testdir = tempdir( CLEANUP => 1 );
  my $instrument_folder = q[AV244103];
  foreach my $experiment_name (qw(NT1234567B NT1234567C NT1234567D)) {
    my $runfolder_name = qq[20250325_${instrument_folder}_${experiment_name}];
    make_run_folder(catdir($testdir, $instrument_folder, $runfolder_name));
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

1;
