use strict;
use warnings;
use Test::More tests => 5;

BEGIN {
  local $ENV{'HOME'}='t';
  use_ok('npg::view::usage');
}

{
  my $uv = {};
  npg::view::usage::list($uv);
  ok (exists $uv->{'staging_area_indexes'}, 'staging areas key exists');
  ok (exists $uv->{'staging_area_prefix'}, 'staging areasprefix key exists');
  is ($uv->{'staging_area_prefix'}, 'sf', 'host prefix captured correctly');
  is (scalar @{$uv->{'staging_area_indexes'}}, 36, 'indexes captured correctly');
}


1;
