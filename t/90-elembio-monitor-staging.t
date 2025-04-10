use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use File::Temp qw/ tempdir /;
use File::Path qw/ make_path /;

use t::dbic_util;

BEGIN {
  local $ENV{'HOME'} = 't';
  use_ok('Monitor::Elembio::Staging');
}

my $schema = t::dbic_util->new->test_schema(fixture_path => q[t/data/dbic_fixtures]);

subtest 'test staging monitor find runs' => sub {
  plan tests => 3;
  my $test;
  lives_ok { $test = Monitor::Elembio::Staging->new( npg_tracking_schema => $schema ) }
        'Object creation ok';
  throws_ok { $test->find_run_folders() }
            qr/Top[ ]level[ ]staging[ ]path[ ]required/msx,
            'Require path argument';
  throws_ok { $test->find_run_folders('/no/such/path') }
            qr/[ ]not[ ]a[ ]directory/msx, 'Require real path';
};

1;
