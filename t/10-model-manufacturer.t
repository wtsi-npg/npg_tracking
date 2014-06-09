use strict;
use warnings;
use Test::More tests => 14;
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

{
  my $m = npg::model::manufacturer->new({
           util => $util,
           id_manufacturer => 10,
          });
  my $ci = $m->current_instruments();
  isa_ok($ci, 'ARRAY');
  is((scalar @{$ci}), 19, 'current instrument size');
}

{
  my $m = npg::model::manufacturer->new({
           util => $util,
           id_manufacturer => 10,
          });
  is($m->instrument_count(), 20, 'instrument count');
}

{
  trap {
    my $m = npg::model::manufacturer->new({
             util => 'bla',
             id_manufacturer => 10,
            });
    is($m->instrument_count(), undef, 'database query failure');
  };
}

{
  my $m = npg::model::manufacturer->new({
           util => $util,
           id_manufacturer => 10,
          });
  my $is = $m->instrument_formats();
  isa_ok($is, 'ARRAY');
  is((scalar @{$is}), 6, 'instrument_formats');
}

{
  my $m = npg::model::manufacturer->new({
           util => $util,
           id_manufacturer => 10,
          });
  my $ms = $m->manufacturers();
  isa_ok($ms, 'ARRAY');
  is((scalar @{$ms}), 3, 'manufacturers');
}

