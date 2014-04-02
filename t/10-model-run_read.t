use strict;
use warnings;
use Test::More tests => 5;
use t::util;

our $READ   = 'npg::model::run_read';

use_ok($READ);

my $util = t::util->new({
       fixtures  => 1,
      });

{
  my $rr = $READ->new({
           util => $util,
          });
  isa_ok($rr, $READ, 'isa ok');
}

{
  my $rr = $READ->new({
           util         => $util,
           id_run       => 1,
           order        => 1,
           intervention => 0,
          });
  ok($rr->create(), 'create');
  isa_ok($rr->run(), 'npg::model::run', 'run object');
  is($rr->run->id_run, 1, 'correct id_run');
}

1;
__END__
