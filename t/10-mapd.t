use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;
use File::Spec::Functions qw(splitpath catfile);
use Cwd qw(cwd);
use File::Path qw(make_path);
use File::Copy;
use File::Temp qw(tempdir);
use File::Find;

use_ok('npg_tracking::data::mapd');

1;