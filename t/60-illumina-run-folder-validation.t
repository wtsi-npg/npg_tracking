use strict;
use warnings;
use Test::More tests => 10;
use Test::Exception;
use Test::Warn;
use DateTime;

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
  warning_like { $result = $v->check() }
    qr/Attribute \(tracking_run\) does not pass the type constraint/,
    'warning for a run that is not in the db';
  ok(!$result, 'not validated');

  my $good_rf = '110818_IL34_06699';
  my $bad_rf  = '110819_IL34_06699';

  $v = $package->new(
     run_folder          => $good_rf,
     npg_tracking_schema => $schema
  );
  ok($v->check, 'validated');

  $v = $package->new(
     run_folder          => $bad_rf,
     npg_tracking_schema => $schema
  );
  warning_like { $result = $v->check() } qr/does\ not\ match/,
    'warning when run folder names mismatch';
  ok(!$result, 'not validated');

  $schema->resultset('Run')->find(6699)->update( {'folder_name' => undef,} );
  $v = $package->new(
     run_folder          => $good_rf,
     npg_tracking_schema => $schema
  );
  warning_like { $result = $v->check }
    qr/Expected run folder name: 000000_UNKNOWN_06699_A_70KV3AAXX/,
    'warning about expected run folder name';
  ok(!$result, 'not validated');

  my $date = DateTime->now();
  my $prev_date = DateTime->now()->subtract(days => 3);
  my $id   = $schema->resultset('RunStatusDict')->search(
    {description => 'run pending'})->next->id_run_status_dict();
  $schema->resultset('RunStatus')->create(
   {id_run_status_dict => $id, iscurrent =>0, id_run => 6699, id_user => 7, date => $date} );
  $schema->resultset('RunStatus')->create(
   {id_run_status_dict => $id, iscurrent =>1, id_run => 6699, id_user => 7, date => $date} );
  $schema->resultset('Run')->find(6699)->update({id_instrument => 67});

  my $expected = substr($date->ymd(q[]), 2) . '_HS8_06699_A_70KV3AAXX';

  $v = $package->new(
     run_folder          => $expected,
     npg_tracking_schema => $schema
  );
  warning_like { $result = $v->check }
    qr/Expected run folder name: $expected/,
    'warning about expected run folder name';
  ok($result, 'validated via expected folder name');
}

1;
