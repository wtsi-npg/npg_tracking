use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use File::Temp qw/ tempdir /;

use_ok( q{npg_tracking::monitor::status} );

my $m = npg_tracking::monitor::status->new(dir => q[t], link => q[t]);
isa_ok($m, q{npg_tracking::monitor::status});
lives_ok { $m->_notifier } 'notifier object created';

my $dir = tempdir(UNLINK => 1);

1;