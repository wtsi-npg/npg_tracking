use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use Test::Warn;

use t::dbic_util;
my $schema = t::dbic_util->new->test_schema(fixture_path => q[t/data/dbic_fixtures]);

my $package = q{npg_tracking::illumina::run::folder::validation};

use_ok($package);

{
  my $v = $package->new(
    run_folder          => '100505_IL45_4655',
    npg_tracking_schema => $schema
  );
  my $result;
  warnings_like { $result = $v->check() }
    [qr/Attribute \(tracking_run\) does not pass the type constraint/,
     qr/does not match \'\'/],
    'warning since the run is not in the db';
  ok(!$result, 'not validated');

  $v = $package->new(
     run_folder          => '110818_IL34_06699',
     npg_tracking_schema => $schema
  );
  ok($v->check, 'validated');

  $v = $package->new(
     run_folder          => '110819_IL34_06699',
     npg_tracking_schema => $schema
  );
  warning_like { $result = $v->check() } qr/does\ not\ match/,
    'warning since the run is not in the db';
  ok(!$result, 'not validated');
}

1;
