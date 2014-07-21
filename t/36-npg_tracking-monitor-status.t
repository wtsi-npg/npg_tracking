use strict;
use warnings;
use Test::More tests => 20;
use Test::Exception;
use Test::Warn;
use File::Temp qw/ tempdir /;

use_ok( q{npg_tracking::monitor::status} );

my $m = npg_tracking::monitor::status->new(transit => q[t]);
isa_ok($m, q{npg_tracking::monitor::status});
lives_ok { $m->_notifier } 'notifier object created';

my $dir = tempdir(UNLINK => 1);
diag $dir;
{
  my $m = npg_tracking::monitor::status->new(transit => $dir);
  lives_ok {$m->_watch_setup} 'watch is set up on an empty directory';
  ok(exists $m->_watch_obj->{$dir}, 'watch object is cached');
  is(ref $m->_watch_obj->{$dir}, q[Linux::Inotify2::Watch], 'correct object type');
  is($m->_watch_obj->{$dir}->name, $dir, 'watch object name'); 
  warning_like {$m->_cancel_watch} qr/canceling watch for $dir/, 'watch cancelled';
  ok(!exists $m->_watch_obj->{$dir}, 'watch object is not cached');
}

{
  my $m = npg_tracking::monitor::status->new(transit => $dir);
  lives_ok {$m->_watch_setup} 'watch is set up on an empty directory';
  my $new_dir = "$dir/test";
  mkdir $new_dir;
  my $pid = fork();
  if ($pid) {
    warnings_like { $m->_notifier->poll() } 
     [qr/$new_dir deleted/, qr/runforder $new_dir watch cancel called/ ],
     'deletion reported';
    wait;
  } else {
    rmdir $new_dir;
    exit 0;
  }
 
  mkdir "$dir/test1";
  mkdir "$dir/test1/test2";  
 
  $pid = fork();
  if ($pid) {
    warnings_like { $m->_notifier->poll() } 
     [qr/$dir\/test2 moved to the watched directory/, qr/runforder $dir\/test2 watch setup called/ ],
     'move reported';
    wait;
  } else {
    `mv $dir/test1/test2 $dir`;
    exit 0;
  }  
}

{
  my $m = npg_tracking::monitor::status->new(transit => $dir);
  my $new_dir = "$dir/test";
  mkdir $new_dir;
  lives_ok {$m->_watch_setup} 'watch is set up on a directory with a subdirectory';
  rmdir $new_dir;
  ok(!-e $new_dir, 'subdirectory has been removed');
  my $count;
  warnings_like { $count = $m->_notifier->poll() } 
     [qr/$new_dir deleted/, qr/runforder $new_dir watch cancel called/ ],
     'deletion reported when polling after the event';
  is($count, 1, 'polled one event');

  my $new_dir1 = "$dir/test1";
  mkdir $new_dir1;
  mkdir $new_dir; 

  $m = npg_tracking::monitor::status->new(transit => $dir);
  lives_ok {$m->_watch_setup} 'watch is set up on a directory with a subdirectory';
  rmdir $new_dir1;
  rmdir $new_dir;
  ok(!-e $new_dir && !-e $new_dir1, 'subdirectories have been removed');
  warnings_like { $count = $m->_notifier->poll() } [
       qr/$new_dir1 deleted/,
       qr/runforder $new_dir1 watch cancel called/,
       qr/$new_dir deleted/,
       qr/runforder $new_dir watch cancel called/,
     ],
     'two deletions reported when polling after two events in the order the events happened';
  is($count, 2, 'polled two event'); 
}

1;