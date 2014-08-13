use strict;
use warnings;
use Test::More tests => 34;
use Test::Exception;
use Test::Warn;
use File::Temp qw/ tempdir /;
use t::dbic_util;

use_ok( q{npg_tracking::status} );
use_ok( q{npg_tracking::monitor::status} );

my $m = npg_tracking::monitor::status->new(transit => q[t]);
isa_ok($m, q{npg_tracking::monitor::status});
lives_ok { $m->_notifier } 'notifier object created';

my $dir = tempdir(UNLINK => 1);

my $cb = sub {
      my $e = shift;
      my $name = $e->fullname;
      if ($e->IN_IGNORED) {
        die "test callback: events for $name have been lost";
      }
      if ($e->IN_UNMOUNT) {
        die "test callback: filesystem unmounted for $name";
      }
      if ($e->IN_DELETE) {
        warn("test callback: $name deleted");
      } elsif ($e->IN_MOVED_TO) {
        warn("test callback: $name moved to the watched directory");
      }
};

{
  my $m = npg_tracking::monitor::status->new(transit => $dir);
  lives_ok {$m->_transit_watch_setup} 'watch is set up on an empty directory';
  ok(exists $m->_watch_obj->{$dir}, 'watch object is cached');
  is(ref $m->_watch_obj->{$dir}, q[Linux::Inotify2::Watch], 'correct object type');
  is($m->_watch_obj->{$dir}->name, $dir, 'watch object name'); 
  warning_like {$m->cancel_watch} qr/canceling watch for $dir/, 'watch cancelled';
  ok(!exists $m->_watch_obj->{$dir}, 'watch object is not cached');
}

{
  my $m = npg_tracking::monitor::status->new(transit => $dir);
  lives_ok {$m->_transit_watch_setup} 'watch is set up on an empty directory';
  my $watch = $m->_watch_obj->{$dir};
  $watch->cb($cb); # Plug in a simplified test callback 
  my $new_dir = "$dir/test";
  mkdir $new_dir;
  my $pid = fork();
  if ($pid) {
    warnings_like { $m->_notifier->poll() } 
     [qr/test callback: $new_dir deleted/],
     'deletion reported';
  } else {
    rmdir $new_dir;
    exit;
  }
  wait;

  mkdir "$dir/test1";
  mkdir "$dir/test1/test2";  
 
  $pid = fork();
  if ($pid) {
    warnings_like { $m->_notifier->poll() } 
     [qr/test callback: $dir\/test2 moved to the watched directory/],
     'move reported';
  } else {
    `mv $dir/test1/test2 $dir`;
    exit 0;
  }
  wait;

  warnings_like { $m->cancel_watch }
    [qr/canceling watch for $dir/],
    'watch cancell reported';
  is(scalar keys %{$m->_watch_obj}, 0, 'watch hash empty');
}

{
  my $m = npg_tracking::monitor::status->new(transit => $dir);
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
    [qr/canceling watch for $dir/], 'watch cancell reported';

  my $new_dir1 = "$dir/test1";
  mkdir $new_dir1;
  mkdir $new_dir; 

  $m = npg_tracking::monitor::status->new(transit => $dir);
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
    [qr/canceling watch for $dir/], 'watch cancell reported'; 
}

my $schema = t::dbic_util->new->test_schema();
{
  my $m = npg_tracking::monitor::status->new(transit => $dir, _schema => $schema);
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
}

{
  my $m = npg_tracking::monitor::status->new(transit => $dir);
  throws_ok {$m->_read_status('path', $dir)}
    qr/Error instantiating object from path: read_file 'path' - sysopen: No such file or directory/,
    'error reading object';
  my $path = npg_tracking::status->new(id_run => 1, status => 'some status', lanes => [8, 7])->to_file($dir); 
  throws_ok {$m->_read_status($path, $dir)} qr/Failed to get id_run from $dir/,
    'error getting id_run from runfolder_path';
}

{
  ok(npg_tracking::monitor::status::_path_is_latest_summary('/some/path/Latest_Summary'),
    'latest summary link identified correctly');
  ok(!npg_tracking::monitor::status::_path_is_latest_summary('/some/path/Latest_Summary/other'),
    'path is not latest summary');
}

1;
