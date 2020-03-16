use strict;
use warnings;
use Test::More tests => 10;

use_ok('st::api::base');

{
  my $base = st::api::base->new();
  isa_ok($base, 'st::api::base');
  like($base->live_url(), qr/sequencescape[.]psd/, 'live_url');
  like($base->dev_url(), qr/dev\.psd/, 'dev_url');
  is((scalar $base->fields()), undef, 'no default fields');
  is($base->primary_key(), undef, 'no default pk');

  is($base->lims_url(), $base->live_url(),'live url returned');
  is($base->service(),  $base->live_url() . q[/],'live url returned');
  {
    local $ENV{'dev'} = 'some';
    is($base->lims_url(), $base->dev_url(), 'dev url returned');
    is($base->service(),  $base->dev_url() . q[/],'dev url returned');
  }

}

1;
