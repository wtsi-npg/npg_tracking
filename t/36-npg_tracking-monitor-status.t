use strict;
use warnings;
use Test::More tests => 114;
use Test::Exception;
use Test::Warn;
use Test::Trap qw/ :stderr(tempfile) /;
use File::Temp qw/ tempdir /;
use File::Path qw/ make_path /;
use DateTime;
use DateTime::TimeZone;
use DateTime::Duration;
use POSIX ":sys_wait_h";
use Cwd;

use t::dbic_util;

use_ok( q{npg_tracking::status} );
use_ok( q{npg_tracking::monitor::status} );

my $dir = tempdir(UNLINK => 1);
my $runfolder_name = '130213_MS2_9334_A_MS2004675-300V2';
my $test_id_run = 9334;
my @bam_basecall = ($runfolder_name, 'Data', 'Intensities', 'BAM_basecalls_20130214-155058');

my $now = DateTime->now(time_zone=> DateTime::TimeZone->new(name => q[local]));

my $util = t::dbic_util->new(fixture_path => undef);
my $schema = $util->test_schema();

# We are going to use MySQL datetime parser so that the DateTime
# objects retrieved from the database have floating time zone and
# not UTC zone as they would have had if the parser matching our
# test db, DateTime::Format::SQLite, were used.
# According to DateTime documentation
# "Compare two DateTime objects... If one of the two DateTime objects has a floating time
# zone, it will first be converted to the time zone of the other object."

$schema->resultset('RunStatus')->result_source->storage->datetime_parser_type('DateTime::Format::MySQL');
$util->load_fixtures($schema, $util->default_fixture_path());

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
  ok($m->enable_inotify, 'inotify is enabled by default');
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
    qr/Error instantiating object from path: read_file 'path'.*No such file or directory/,
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
  _create_test_run($schema, $test_id_run);
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
  my $status_file_path = npg_tracking::status->new(
      id_run => $test_id_run,
      lanes  => \@lanes,
      status => $lane_status,
  )->to_file($status_dir);

  is( $m->_notifier->poll(), 1, 'new lane status file creation registered');
  @rows = $schema->resultset('RunLaneStatus')->search(
     { 'run_lane.id_run'                  => $test_id_run,
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

  is($run->current_run_status_description, $lane_status,
    'current run status has not changed');

  is( $m->_notifier->poll(), 0, 'no further events');

  my $opath = join q[/], $o, $runfolder_name;
  rename $new_path, $opath;

  lives_ok { $m->_read_status($status_file_path, $opath) } 'processing transit path when file is in destination';
  my $moved = $status_file_path;
  $moved =~ s/$a/$o/smx;
  my $af = "$a/test.json";
  rename $moved, $af;
  my $given = $af;
  my $of = "$o/test.json";
  is($m->_find_path($of), $af, 'give file in destination - find in transit');
  rename $af, $of;
  is($m->_find_path($af), $of, 'file in transit - find in destination');
  unlink $of;
  ok(!$m->_find_path($af), 'file does not exist in either directory - path not found');

  open my $fh, '>', $moved;
  print $fh 'not json' or die "failed to print to $moved";
  close $fh or die "failed to close $moved";
  throws_ok { $m->_read_status($status_file_path, $opath) }
     qr/Error instantiating object from $moved/,
    'processing transit path (invalid json) when file is in destination';
}

{
  my $tdir = tempdir(UNLINK => 1);
  _runfolder($tdir);
  my $status_dir = _create_status_dir($tdir);

  my ($a, $o) = _staging_dir_tree($tdir);
  my $m = npg_tracking::monitor::status->new(transit     => $a,
                                             blocking    => 0,
                                             _schema     => $schema,
                                             verbose     => 0,);
  lives_ok { $m->_transit_watch_setup() } 'transit dir watch set-up';

  my $old_path = join q[/], $tdir, $runfolder_name;
  my $new_path = join q[/], $a, $runfolder_name;
  rename $old_path, $new_path;

  is( $m->_notifier->poll(), 1, 'runfolder move to transit detected');
  is( ref $m->_watch_obj->{$runfolder_name}->{'top_level'}, 'Linux::Inotify2::Watch',
    'watch object for the runfolder is cached');
  ok( !exists $m->_watch_obj->{$runfolder_name}->{'status_dir'},
    'no summary link - watch object for the status directory has not been created yet');

  my $format = npg_tracking::status->_timestamp_format();
  my $date = DateTime->now(time_zone => DateTime::TimeZone->new(name => q[local]));
  $date->add_duration(DateTime::Duration->new(seconds => 10));
  $status_dir =~ s/$tdir/$a/xms;
  my $status1 = 'archival pending';
  npg_tracking::status->new(
      id_run => $test_id_run,
      status => $status1,
      timestamp => $date->strftime($format),
  )->to_file($status_dir);

  $date->add_duration(DateTime::Duration->new(seconds => 1));
  my $status2 = 'archival in progress';
  npg_tracking::status->new(
      id_run => $test_id_run,
      status => $status2,
      timestamp => $date->strftime($format),
  )->to_file($status_dir);

  my $count = $schema->resultset('RunStatus')->search(
     { 'id_run' => $test_id_run,})->count();

  my $link = _create_latest_summary_link($a);
  is( $m->_notifier->poll(), 1, 'summary link creation detected');
  is( ref $m->_watch_obj->{$runfolder_name}->{'status_dir'}, 'Linux::Inotify2::Watch',
    'watch object for the status directory is cached');

  my @rows = $schema->resultset('RunStatus')->search(
     { 'id_run'                      => $test_id_run,},
     {prefetch => 'run_status_dict',
      order_by => { -desc => 'date'},},
  )->all();
  ok (scalar @rows == $count + 2, 'two new run statuses added');
  my $run_status_obj = shift @rows;
  is ($run_status_obj->run_status_dict->description, $status2, 'status from the latest status file saved');
  $run_status_obj = shift @rows;
  is ($run_status_obj->run_status_dict->description, $status1, 'status from the next to latest status file saved');

  $date->add_duration(DateTime::Duration->new(seconds => 1));
  $status2 = 'qc complete';
  npg_tracking::status->new(
      id_run => $test_id_run,
      status => $status2,
      timestamp => $date->strftime($format),
  )->to_file($status_dir);

  is( $m->_notifier->poll(), 1, 'file creation detected');
  @rows = $schema->resultset('RunStatus')->search(
     { 'id_run'                      => $test_id_run,},
     {prefetch => 'run_status_dict',
      order_by => { -desc => 'date'},},
  )->all();
  ok (scalar @rows == $count + 3, 'a new run statuses added');
  $run_status_obj = shift @rows;
  is ($run_status_obj->run_status_dict->description, $status2, 'status from the latest status file saved');
}

{
  my $m = npg_tracking::monitor::status->new(transit => $dir, enable_inotify => 0);
  ok(!$m->enable_inotify, 'inotify is disabled');
  is($m->polling_interval, 60, 'default polling interval');

  $m = npg_tracking::monitor::status->new(transit          => $dir,
                                          enable_inotify   => 0,
                                          polling_interval => 1);
  my $pid = fork();
  if ($pid) {
    sleep 3;
    kill 'HUP', $pid;
  } else {
    trap { $m->watch() };
  }
  ok (wait(), 'process terminated');
}

{
  my $new_dir = "$dir/ILorHSany_sf51";
  if (-e $new_dir && !-d $new_dir) {
    unlink $new_dir;
  }
  -e $new_dir or mkdir $new_dir;
  mkdir $new_dir . '/outgoing';
  mkdir $new_dir . '/analysis';

  my $pid = fork();
  if ($pid) {
    sleep 1;
    is (waitpid($pid, WNOHANG), 0, 'process is running');
    sleep 2;
    kill 'HUP', $pid;
  } else {
    my $command = getcwd . '/bin/npg_status_watcher';
    exec("$command --prefix $dir");
  }
  ok (wait(), 'process terminated');
}

{
  throws_ok { npg_tracking::monitor::status->staging_fs_type() }
    qr/Existing path required/, 'path argument is required';
  throws_ok { npg_tracking::monitor::status->staging_fs_type('t/some_path') }
    qr/Existing path required/, 'path should exist';
  ok (npg_tracking::monitor::status->staging_fs_type('t'),
    'file system type returned');
  ok (npg_tracking::monitor::status->staging_fs_type('/tmp'),
    'file system type returned');
}

{
  my $base = tempdir(UNLINK => 1);
  _runfolder($base);
  my $rf_path = join q[/], $base, $runfolder_name;
  my $id_run = 9334;

  $schema->resultset('RunStatus')->search({id_run => $id_run})->delete;
  is ($schema->resultset('RunStatus')->search({id_run => $id_run})->count(),
     0, "no run statuses for run $id_run");

  my @files = map {$_->to_file($base)}
              map {npg_tracking::status->new(id_run => $id_run, status => $_)}
              ('analysis in progress', 'secondary analysis in progress',
               'qc review pending', 'archival in progress', 'run archived',
               'qc complete');

  my $m = npg_tracking::monitor::status->new(transit        => $dir,
                                             enable_inotify => 0,
                                             _schema        => $schema);
  for my $method (qw/_cache_file _file_in_cache/) {
    ok ($m->can($method),"$method available");
  }

  my @arg_files = (shift @files);
  trap {is ($m->_update_status4files(\@arg_files, $rf_path), 1, '1 file saved')};
  ok ($m->_file_in_cache($arg_files[0]), 'file cached');

  push @arg_files, shift @files;
  trap {is ($m->_update_status4files(\@arg_files, $rf_path), 1, '1 file saved')};
  ok ($m->_file_in_cache($arg_files[1]), 'file cached');

  trap {is ($m->_update_status4files(\@files, $rf_path), 4, '4 files saved')};
  foreach my $f (@files) {
    ok ($m->_file_in_cache($f), 'file cached');
  }
  trap {is ($m->_update_status4files(\@files, $rf_path), 0, 'no files saved')};

  my $f = npg_tracking::status->new(id_run => $id_run, status => 'some')
                              ->to_file($base);
  trap {is ($m->_update_status4files([$f], $rf_path), 0, 'no files saved')};
  ok (!$m->_file_in_cache($f), 'file not cached');

  is ($schema->resultset('RunStatus')->search({id_run => $id_run})->count(),
     scalar @files + scalar  @arg_files, 'correct number of statuses saved');
}

1;
