use strict;
use warnings;
use Test::More tests => 6;
use t::util;
use Test::Trap;

use_ok('npg::model::manufacturer');

my $util = t::util->new({fixtures=>1});

{
  my $m = npg::model::manufacturer->new({util=>$util});
  isa_ok($m, 'npg::model::manufacturer');
}

{
  trap {
    my $m = npg::model::manufacturer->new({
             util => 'foo',
             name => 'fail!',
            });
    is($m->init(), undef, 'database query failure');
  };
}

{
  my $m = npg::model::manufacturer->new({
           util => $util,
           name => 'not present',
          });
  is($m->id_manufacturer(), undef, 'no lookup by name');
}

{
  my $m = npg::model::manufacturer->new({
           util => $util,
           name => 'Applied Biosystems',
          });
  is($m->id_manufacturer(), 20, 'load by name');
}

{
  my $m = npg::model::manufacturer->new({
           util => $util,
           id_manufacturer => 10,
          });
  is($m->name(), 'Illumina', 'load by id');
}

1;
