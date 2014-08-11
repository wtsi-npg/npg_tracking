use strict;
use warnings;
use English qw{-no_match_vars};
use Test::More tests => 12;
use File::Temp qw{ tempdir };
use File::Slurp;

my $tempdir = tempdir(CLEANUP => 1,);
my $script = 'bin/npg_status2file';

use_ok(q{npg_tracking::status});

qx{perl $script --dir_out /some --id_run 3 --status 'some status' };
ok($CHILD_ERROR, qq{child error executing the script since the output directory does not exist});

qx{perl $script --dir_out $tempdir --id_run 3 --status 'some status' };
ok(!$CHILD_ERROR, q{no child error executing the script});
my $file = join q[/], $tempdir, 'some-status.json';
ok(-e $file, 'output file exists');
my $text = read_file($file);
my $obj = npg_tracking::status->thaw($text);
is($obj->id_run, 3, 'id_run from serialized object');
is($obj->status, 'some status', 'status from serialized object');
is(scalar @{$obj->lanes}, 0, 'lanes array is empty');

qx{perl $script --dir_out $tempdir --id_run 5 --status 'other-status' --lanes 3 --lanes 2};
ok(!$CHILD_ERROR, qq{no child error executing the script});
$file = join q[/], $tempdir, 'other-status_2_3.json';
ok(-e $file, 'output file exists');
$text = read_file($file);
$obj = npg_tracking::status->thaw($text);
is($obj->id_run, 5, 'id_run from serialized object');
is($obj->status, 'other-status', 'status from serialized object');
is(join(q[ ], @{$obj->lanes}), q[3 2], 'lanes array from serialized object');

1;