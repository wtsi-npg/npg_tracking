use strict;
use warnings;
use Test::More tests => 2;

use_ok('st::api::batch');
my $batch = st::api::batch->new();
isa_ok($batch, 'st::api::batch');

1;
