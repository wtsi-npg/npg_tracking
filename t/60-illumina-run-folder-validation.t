use strict;
use warnings;
use Test::More tests => 9;
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
  warnings_like { $result = $v->check() }
    [qr/Attribute \(tracking_run\) does not pass the type constraint/,
     qr/Neither run folder name nor run status is available/],
    'warnings for a run that is not in the db';
  ok(!$result, 'not validated');

  my $id = $schema->resultset('RunStatusDict')->search({description => 'run in progress'})->next->id_run_status_dict();
  $schema->resultset('RunStatus')->create(
   {id_run_status_dict => $id, iscurrent =>1, id_run => 6699, id_user => 7, date => DateTime->now()} );

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
    qr/No run folder name for run with status \'run in progress\'/,
    'warning about missing run folder name';
  ok(!$result, 'not validated: run in progress, no name');

  $id = $schema->resultset('RunStatusDict')->search({description => 'run pending'})->next->id_run_status_dict();
  $schema->resultset('Run')->find(6699)->current_run_status->update( {id_run_status_dict => $id} );

  $v = $package->new(
     run_folder          => $good_rf,
     npg_tracking_schema => $schema
  );
  ok($v->check, 'validated: run pending, no name');
}

1;
