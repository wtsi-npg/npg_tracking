use strict;
use warnings;
use Test::More tests => 24;
use Test::Exception;
use Test::Warn;
use File::Temp qw/ tempdir /;

use_ok( q{npg_tracking::monitor::status} );

my $m = npg_tracking::monitor::status->new(transit => q[t]);
isa_ok($m, q{npg_tracking::monitor::status});
lives_ok { $m->_notifier } 'notifier object created';

my $dir = tempdir(UNLINK => 1);
#diag $dir;

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

1;
