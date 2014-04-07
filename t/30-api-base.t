use strict;
use warnings;
use Test::More tests => 6;

use_ok('npg::api::base');

my $base1 = npg::api::base->new();
isa_ok($base1->util(), 'npg::api::util', 'constructs');

my $base2 = npg::api::base->new({
         util        => $base1->util(),
        });
is($base1->util(), $base2->util(), 'yields the util given on construction');

$base2->{'read_dom'} = 'foo';
$base2->flush();
is($base2->{'read_dom'}, undef, 'dom cache flushes');
is($base2->fields(), (), 'no fields in base class');
is($base2->large_fields(), (), 'no large fields in base class');

1;
