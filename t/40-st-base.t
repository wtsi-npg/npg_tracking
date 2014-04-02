use strict;
use warnings;
use Test::More tests => 6;

use_ok('st::api::base');

{
  my $base = st::api::base->new();
  isa_ok($base, 'st::api::base');
  like($base->live_url(), qr/psd\-support/, 'live_url');
  like($base->dev_url(), qr/psd\-dev/, 'dev_url');
  is((scalar $base->fields()), undef, 'no default fields');
  is($base->primary_key(), undef, 'no default pk');
}

1;
