use strict;
use warnings;
use Test::More tests => 42;
use Test::Exception;
use DateTime;
use DateTime::Duration;

use t::dbic_util;

use_ok( q{npg_tracking::Schema::Result::RunLane} );

my $schema = t::dbic_util->new->test_schema();

my $rs;
lives_ok {
  $rs = $schema->resultset( q{RunLane} )->search({id_run => 1,});
} q{obtain a result set ok};

is ($rs->count, 2, 'two rows retrieved');
lives_ok {
   $schema->resultset( q{RunLane} )->create({id_run => 1, position => 5});
   $schema->resultset( q{RunLane} )->create({id_run => 1, position => 6});
} 'two more rows created';

my @lanes = $schema->resultset( q{RunLane} )
             ->search({id_run => 1}, {'order_by' => 'position'})->all;
is (scalar @lanes, 4, 'four rows retrieved');

my $run = $lanes[0]->run;
is ($run->id_run, 1, 'run retrieved correctly');
is($run->current_run_status_description, 'run complete',
  'current run status');

{
  ok(!$lanes[0]->current_run_lane_status, 'current status not set');
  my $now = DateTime->now();
  my $new = $lanes[0]->update_status('analysis complete');
  isa_ok( $new, 'npg_tracking::Schema::Result::RunLaneStatus');
  is($new->run_lane_status_dict->description, 'analysis complete', 'status as set');
  is($new->user->username, 'pipeline', 'status assigned to the pipeline user');
  is($new->iscurrent, 1, 'new status is marked as current');
  is($lanes[0]->current_run_lane_status->run_lane_status_dict->description,
    'analysis complete', 'current status returned correctly');
  is($run->current_run_status_description, 'run complete',
    'run status has not changed');

  ok(!$lanes[1]->current_run_lane_status, 'current status not set');
  $new = $lanes[1]->update_status('analysis complete', 'joe_loader');
  is($new->run_lane_status_dict->description, 'analysis complete', 'status as set');
  is($new->user->username, 'joe_loader', 'username as given');
  is($new->iscurrent, 1, 'new status is marked as current');
  is($lanes[1]->current_run_lane_status->run_lane_status_dict->description,
    'analysis complete', 'current status returned correctly');
  is($run->current_run_status_description, 'run complete',
    'run status has not changed');

  sleep 1;
  $new = $lanes[2]->update_status('analysis complete', 'joe_loader', $now);
  is($new->run_lane_status_dict->description, 'analysis complete', 'status as set');
  is($new->user->username, 'joe_loader', 'username as given');
  is($new->date->datetime, $now->datetime, 'timestamp as given');
  is($new->iscurrent, 1, 'new status is marked as current');
  is($run->current_run_status_description, 'run complete',
    'run status has not changed');

  $new = $lanes[3]->update_status('analysis complete', undef, $now);
  is($new->run_lane_status_dict->description, 'analysis complete', 'status as set');
  is($new->user->username, 'pipeline', 'status assigned to the pipeline user');
  is($new->date->datetime, $now->datetime, 'timestamp as given');
  is($new->iscurrent, 1, 'new status is marked as current');
  is($run->current_run_status_description, 'qc review pending',
    'run status has changed');
 
  $new = $lanes[3]->update_status('analysis complete');
  ok(!$new, 'new row is not created');
  
  my $old_date = $now->subtract_duration(DateTime::Duration->new(seconds => 1));
  $new = $lanes[3]->update_status('analysis in progress', undef, $old_date);
  isa_ok( $new, 'npg_tracking::Schema::Result::RunLaneStatus');
  is($new->run_lane_status_dict->description, 'analysis in progress', 'status as set');
  is($new->date->datetime, $old_date->datetime, 'timestamp as given');
  is($new->user->username, 'pipeline', 'status assigned to the pipeline user');
  is($new->iscurrent, 0, 'new status is not marked as current');
  is($lanes[3]->current_run_lane_status->run_lane_status_dict->description,
    'analysis complete', 'current lane status has not changed');
}

{
  foreach my $lane (@lanes) {
    $lane->update_status('manual qc complete');
  }
  is($run->current_run_status_description, 'archival pending',
    'run status has changed');
}

{
  my $current_row = $lanes[0]->current_run_lane_status;
  my $current_date = $current_row->date;
  my $current_status = $current_row->run_lane_status_dict->description;

  my $older_date = $current_date->subtract_duration(DateTime::Duration->new(seconds => 1));
  my $new_row = $lanes[0]->update_status($current_status, undef, $older_date);
  isa_ok( $new_row, q{npg_tracking::Schema::Result::RunLaneStatus}, 'new row created'); 
  ok(!$new_row->iscurrent, 'new row is not marked as current');
  is($new_row->date, $older_date, 'new status has correct date');
  $new_row = $lanes[0]->update_status($current_status, 'some user');
  ok(!$new_row, 'duplicated row is not created');
}

1;