use strict;
use warnings;
use Test::More tests => 71;
use Test::Exception;
use Test::Warn;
use Test::Trap qw/ :stderr(tempfile) /;
use File::Temp qw/ tempdir /;
use File::Path qw/ make_path /;
use DateTime;
use DateTime::TimeZone;
use DateTime::Duration;
use t::dbic_util;

use_ok( q{npg_tracking::status} );
use_ok( q{npg_tracking::monitor::status} );

my $dir = tempdir(UNLINK => 1);
my $runfolder_name = '130213_MS2_9334_A_MS2004675-300V2';
my $test_id_run = 9334;
my @bam_basecall = ($runfolder_name, 'Data', 'Intensities', 'BAM_basecalls_20130214-155058');

my $now = DateTime->now(time_zone=> DateTime::TimeZone->new(name => q[local]));

my $schema = t::dbic_util->new()->test_schema();

sub _staging_dir_tree {
  my $root = shift;
  my $a = join(q[/], $root, 'analysis');
  my $o = join(q[/], $root, 'outgoing');
  mkdir $a;
  mkdir $o;
  return ($a, $o);
}

sub _runfolder {
  my $root = shift;
  my @dirs = @bam_basecall;
  unshift @dirs, $root;
  make_path join(q[/], @dirs);
  my @original = @dirs;
  pop @dirs;
  push @dirs, 'BaseCalls';
  make_path join(q[/], @dirs);
  push @original, 'no_cal';
  make_path join(q[/], @original);
}

sub _create_status_dir{
  my $root = shift;
  my @dirs = @bam_basecall;
  unshift @dirs, $root;
  push @dirs, 'status';
  my $status_dir = join(q[/], @dirs);
  make_path $status_dir;
  return $status_dir;
}

sub _create_latest_summary_link {
  my $root = shift;
  my @dirs = @bam_basecall;
  unshift @dirs, $root;
  my $target = join(q[/], @dirs);
  my $link = join(q[/], $root, $runfolder_name, 'Latest_Summary');
  symlink $target, $link;
  return $link;
}

sub _create_test_run {
  my ($schema, $id_run) = @_;;
  my $run = $schema->resultset('Run')->create({
       id_run        => $id_run,
       id_instrument => 48,
       team          => 'A',
                                   });
  foreach my $lane ((1 .. 8)) {
    $schema->resultset('RunLane')->create({
       id_run => $id_run,
       position => $lane,
                                       });
  }
  $now->subtract_duration(DateTime::Duration->new(seconds => 10));
  $run->update_run_status('run pending', undef, $now);
  $now->add_duration(DateTime::Duration->new(seconds => 1));
  $run->update_run_status('run complete', undef, $now);
  $now->add_duration(DateTime::Duration->new(seconds => 1));
  $run->update_run_status('run mirrored', undef, $now);
  $run->update_run_status('analysis pending', undef, $now);
}

my $cb = sub {
  my $e = shift;
  my $name = $e->fullname;
  if ($e->IN_IGNORED) {
    warn "test callback: events for $name have been lost";
  } elsif ($e->IN_DELETE) {
    warn "test callback: $name deleted\n";
  } elsif ($e->IN_MOVED_TO) {
    warn "test callback: $name moved to the watched directory\n";
  }
};

{
  my $m = npg_tracking::monitor::status->new(transit => $dir, blocking => 0);
  isa_ok($m, q{npg_tracking::monitor::status});
  lives_ok {$m->_transit_watch_setup} 'watch is set up on an empty directory';
  ok(exists $m->_watch_obj->{$dir}, 'watch object is cached');
  is(ref $m->_watch_obj->{$dir}, q[Linux::Inotify2::Watch], 'correct object type');
  is($m->_watch_obj->{$dir}->name, $dir, 'watch object name'); 
  warning_like {$m->cancel_watch} qr/Canceling watch for $dir/, 'watch cancelled';
  ok(!exists $m->_watch_obj->{$dir}, 'watch object is not cached');
}

{
  SKIP: {
    skip 'Travis: inotify does not detect deletion from /tmp', 2 unless !$ENV{'TRAVIS'};
    my $m = npg_tracking::monitor::status->new(transit => $dir);
    lives_ok {$m->_transit_watch_setup} 'watch is set up on an empty directory';
    my $watch = $m->_watch_obj->{$dir};
    $watch->cb($cb); # Plug in a simplified test callback
    my $new_dir = "$dir/test";
    mkdir $new_dir;
    my $pid = fork();
    if ($pid) {
      warnings_exist { $m->_notifier->poll() } 
        [qr/test callback: $new_dir deleted/],
        'deletion reported';
    } else {
      rmdir $new_dir;
      trap { $m->cancel_watch; };
      exit 0;
    }
    wait;
    trap { $m->cancel_watch; };
  };

  my $m = npg_tracking::monitor::status->new(transit => $dir);
  $m->_transit_watch_setup();
  my $watch = $m->_watch_obj->{$dir};
  $watch->cb($cb); # Plug in a simplified test callback
  mkdir "$dir/test1";
  mkdir "$dir/test1/test2";
  my $pid = fork();
  if ($pid) {  
    warnings_like { $m->_notifier->poll() } 
     [qr/test callback: $dir\/test2 moved to the watched directory/],
     'move reported';
  } else {
    `mv $dir/test1/test2 $dir`;
    trap { $m->cancel_watch; };
    exit 0;
  }
  wait;

  warnings_like { $m->cancel_watch }
    [qr/Canceling watch for $dir/], 'watch cancell reported';
  is(scalar keys %{$m->_watch_obj}, 0, 'watch hash empty');
}

{
  my $m = npg_tracking::monitor::status->new(transit => $dir, blocking => 0);
  my $new_dir = "$dir/test";
  mkdir $new_dir;
  lives_ok {$m->_transit_watch_setup} 'watch is set up on a directory with a subdirectory';
  $m->_watch_obj->{$dir}->cb($cb); # Plug in a simplified test callback
  rmdir $new_dir;
  ok(!-e $new_dir, 'subdirectory has been removed');
  my $count;
  warnings_like { $count = $m->_notifier->poll() } 
     [qr/test callback: $new_dir deleted/],
     'deletion reported when polling after the event';
  is($count, 1, 'polled one event');
  warnings_like { $m->cancel_watch }
    [qr/Canceling watch for $dir/], 'watch cancell reported';

  my $new_dir1 = "$dir/test1";
  mkdir $new_dir1;
  mkdir $new_dir; 

  $m = npg_tracking::monitor::status->new(transit => $dir, blocking => 0);
  lives_ok {$m->_transit_watch_setup} 'watch is set up on a directory with a subdirectory';
  $m->_watch_obj->{$dir}->cb($cb); # Plug in a simplified test callback
  rmdir $new_dir1;
  rmdir $new_dir;
  ok(!-e $new_dir && !-e $new_dir1, 'subdirectories have been removed');
  warnings_like { $count = $m->_notifier->poll() } [
       qr/test callback: $new_dir1 deleted/,
       qr/test callback: $new_dir deleted/,
     ],
     'two deletions reported when polling after two events in the order the events happened';
  is($count, 2, 'polled two event');
  warnings_like { $m->cancel_watch }
    [qr/Canceling watch for $dir/], 'watch cancell reported'; 
}

{
  my $m = npg_tracking::monitor::status->new(transit => $dir, blocking=> 0,  _schema => $schema);
  my $s = npg_tracking::status->new(id_run => 9999, status => 'some status');
  throws_ok {$m->_update_status($s)} qr/Run id 9999 does not exist/,
    'error saving status for non-existing run';
  $s = npg_tracking::status->new(id_run => 1, status => 'some status');
  throws_ok {$m->_update_status($s)} qr/Status 'some status' does not exist in RunStatusDict /,
    'error saving non-existing run status';
  $s = npg_tracking::status->new(id_run => 1, status => 'some status', timestamp => 'some time');
  throws_ok {$m->_update_status($s)} qr/Your datetime does not match your pattern/,
    'error converting timestamp to an object';
  $s = npg_tracking::status->new(id_run => 1, status => 'some status', lanes => [8, 7, 3]);
  throws_ok {$m->_update_status($s)} qr/Lane 3 does not exist in run 1/,
    'error saving status for a list of lanes that includes non-existing lane';
  $s = npg_tracking::status->new(id_run => 1, status => 'some status', lanes => [8, 7]);
  throws_ok {$m->_update_status($s)} qr/Status 'some status' does not exist in RunLaneStatusDict/,
    'error saving non-existing lane status';

  throws_ok {$m->_read_status('path', $dir)}
    qr/Error instantiating object from path: read_file 'path' - sysopen: No such file or directory/,
    'error reading object';
  my $path = npg_tracking::status->new(id_run => 1, status => 'some status', lanes => [8, 7])->to_file($dir); 
  throws_ok {$m->_read_status($path, $dir)} qr/Failed to get id_run from $dir/,
    'error getting id_run from runfolder_path';
  
  ok($m->_path_is_latest_summary('/some/path/Latest_Summary'),
    'latest summary link identified correctly');
  ok(!$m->_path_is_latest_summary('/some/path/Latest_Summary/other'),
    'path is not latest summary');
}

{
  my ($a, $o) = _staging_dir_tree($dir);
  my $m = npg_tracking::monitor::status->new(transit     => $a,
                                             destination => $o,
                                             blocking    => 0,
                                             _schema     => $schema,
                                             verbose     => 0);
  lives_ok { $m->_transit_watch_setup() } 'transit dir watch set-up';
  is(ref $m->_watch_obj->{$a}, 'Linux::Inotify2::Watch', 'watch object for the transit dir is cached');
  is($m->_watch_obj->{$a}->name, $a, 'transit dir path is used as name');
  lives_ok { $m->_stock_watch_setup() } 'existing runfolders watch set-up - no runfolders exist';
  lives_ok { $m->_stock_status_check() } 'stock status check - no runfolders exist';
  is (scalar keys %{$m->_watch_obj}, 1, 'one watch object');
  
  rmdir $a;
  SKIP: {
    skip 'Travis: inotify does not detect deletion from /tmp', 2 unless !$ENV{'TRAVIS'};
    throws_ok {$m->_notifier->poll()} qr/Events for $a have been lost/, 'error when transit directory is deleted';
    is (scalar keys %{$m->_watch_obj}, 0, 'no watch objects');
  };
}

{
  my ($a, $o) = _staging_dir_tree($dir);
  my $m = npg_tracking::monitor::status->new(transit     => $a,
                                             destination => $o,
                                             blocking    => 0,
                                             _schema     => $schema,
                                             verbose     => 0,);
  _runfolder($o);
  lives_ok { $m->_transit_watch_setup() } 'transit dir watch set-up';
  lives_ok { $m->_stock_watch_setup() }
    'existing runfolders watch set-up - one runfolder exists';
  is(ref $m->_watch_obj->{$runfolder_name}->{'top_level'}, 'Linux::Inotify2::Watch',
    'watch object for the runfolder is cached');
  lives_ok { $m->_stock_status_check() }
    'stock status check - one runfolders exist, no status dir';

  my $link = _create_latest_summary_link($o);
  is( $m->_notifier->poll(), 1, 'creating latest summary link registered');
  unlink $link;
  is( $m->_notifier->poll(), 1, 'deleting latest summary link registered');

  my $status_dir = _create_status_dir($o);
  $link = _create_latest_summary_link($o);
  is( $m->_notifier->poll(), 1, 'creating latest summary link registered');
  is( ref $m->_watch_obj->{$runfolder_name}->{'status_dir'},
     'Linux::Inotify2::Watch', 'watch object for the status directory is cached');
  my $old = $m->_watch_obj->{$runfolder_name}->{'status_dir'};  
  rmdir $status_dir;
  unlink $link;

  _create_status_dir($o);
  _create_latest_summary_link($o);
  $m->_notifier->poll();
  is( ref $m->_watch_obj->{$runfolder_name}->{'status_dir'}, 'Linux::Inotify2::Watch',
    'watch object for the status directory is cached');
  ok( $old != $m->_watch_obj->{$runfolder_name}->{'status_dir'},
     'different watch object is cashed');

  my $new_path = join(q[/], $a, $runfolder_name);
  my $old_path = join(q[/], $o, $runfolder_name);

  rename $old_path, $new_path;
  ok (-e $new_path, 'runfolder has been moved');
  is( $m->_notifier->poll(), 1, 'registered moving runfolder to the transit directory');

  rename $new_path, $old_path;
  ok (-e $old_path, 'runfolder has been moved');
  is( $m->_notifier->poll(), 0, 'moving runfolder from the transit directory is not registered');

  $m->cancel_watch();
}

{
  _create_test_run($schema, 9334);
  my $tdir = tempdir(UNLINK => 1);
  _runfolder($tdir);
  my $link = _create_latest_summary_link($tdir);
  my $status_dir = _create_status_dir($tdir);

  my ($a, $o) = _staging_dir_tree($tdir);
  my $m = npg_tracking::monitor::status->new(transit     => $a,
                                             destination => $o,
                                             blocking    => 0,
                                             _schema     => $schema,
                                             verbose     => 0,);
  lives_ok { $m->_transit_watch_setup() } 'transit dir watch set-up';

  my $old_path = join q[/], $tdir, $runfolder_name;
  my $new_path = join q[/], $a, $runfolder_name;
  rename $old_path, $new_path;

  is( $m->_notifier->poll(), 1, 'runfolder move to transit detected');
  is(ref $m->_watch_obj->{$runfolder_name}->{'top_level'}, 'Linux::Inotify2::Watch',
    'watch object for the runfolder is cached');
  is( ref $m->_watch_obj->{$runfolder_name}->{'status_dir'}, 'Linux::Inotify2::Watch',
    'watch object for the status directory is cached');

  my $run = $schema->resultset('Run')->find($test_id_run);
  is($run->current_run_status_description, 'analysis pending', 'current run status');

  $status_dir =~ s/$tdir/$a/smx;
  my $status = 'analysis in progress';
  npg_tracking::status->new(
      id_run => $test_id_run,
      status => $status,
  )->to_file($status_dir);

  is( $m->_notifier->poll(), 1, 'new run status file creation registered');

  is($run->current_run_status_description, $status,
    'current run status set to the new status from file');

  lives_ok { $m->_stock_watch_setup() } 'existing runfolders watch set-up';

  lives_ok { $m->_stock_status_check() } 'stock status check';
  my @rows = $schema->resultset('RunStatus')->search(
     { 'id_run'                      => $test_id_run,
       'run_status_dict.description' => $status,
     },
     {prefetch => 'run_status_dict',},
  )->all;
  is( scalar @rows, 1, 'duplicate run statuses are not created');

  my $lane_status = 'analysis complete';
  my @lanes = (1 .. 8);
  npg_tracking::status->new(
      id_run => $test_id_run,
      lanes  => \@lanes,
      status => $lane_status,
  )->to_file($status_dir);

  is( $m->_notifier->poll(), 1, 'new lane status file creation registered');
  @rows = $schema->resultset('RunLaneStatus')->search(
     { 'run_lane.id_run'                           => $test_id_run,
       'run_lane_status_dict.description' => $lane_status,
       'iscurrent'                        => 1,
     },
     {prefetch => ['run_lane', 'run_lane_status_dict'],,},
  )->all;
  is( scalar @rows, 8, 'eight current lane statuses are created');

  lives_ok { $m->_stock_status_check() } 'stock status check';
  @rows = $schema->resultset('RunLaneStatus')->search(
     { 'run_lane.id_run'                  => $test_id_run,
       'run_lane_status_dict.description' => $lane_status,
     },
     {prefetch => ['run_lane', 'run_lane_status_dict'],},
  )->all;
  is( scalar @rows, 8, 'duplicate lane statuses are not created');
  is($run->current_run_status_description, $status,
    'current run status has not changed');

  is( $m->_notifier->poll(), 0, 'no further events');
}

1;
