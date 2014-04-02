package reference;

use strict;
use warnings;
use Test::More tests => 2;

use_ok('npg_tracking::data::reference::info');

{
  my $ruser = npg_tracking::data::reference::info->new();
  isa_ok($ruser, 'npg_tracking::data::reference::info');
}
