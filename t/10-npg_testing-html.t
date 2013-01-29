use strict;
use warnings;
use Test::More tests => 2;

my @subs = qw(html_tidy_ok);
use_ok( 'npg_testing::html', @subs);
can_ok(__PACKAGE__, 'html_tidy_ok');

1;