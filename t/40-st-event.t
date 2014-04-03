use strict;
use warnings;
use Test::More tests => 24;
use Test::Exception;
use t::useragent;
use npg::api::util;

use_ok('st::api::event');

{
  my $ua = t::useragent->new({
            is_success => 1,
           });
  my $mock = {
        q(http://psd-support.internal.sanger.ac.uk:6600/events)  => $ua,
       };
  $ua->{mock} = $mock;
  my $ev = st::api::event->new({
            util => npg::api::util->new({useragent =>  $ua,}), 
            sample_id   => 11,
            });

  isa_ok($ev, 'st::api::event');
  is($ev->entity_name(), 'event', 'entity_name returns event');
  is($ev->live(), 'http://psd-support.internal.sanger.ac.uk:6600/events',
    'live url returned');
  is($ev->dev(), 'http://psd-dev.internal.sanger.ac.uk:6800/events',
    'dev url returned');
  is($ev->fields(), 'key', 'last of fields is key');

  my $XML = q[<?xml version='1.0'?><event><message>Run 10 : %s</message><eventful_id>11</eventful_id><eventful_type>Item</eventful_type><family>%s</family><identifier>10</identifier><key>%s</key><location>4</location></event>];

  my $STATES = {
    'run pending'              => 'start',
    'analysis pending'         => 'start',
    'archival pending'         => 'start',
    'qc review pending'        => 'start',
    'analysis prelim'          => 'start',
    'run cancelled'            => 'complete',
    'run complete'             => 'complete',
    'analysis complete'        => 'complete',
    'analysis cancelled'       => 'complete',
    'run archived'             => 'complete',
    'analysis prelim complete' => 'complete',
    'run quarantined'          => 'complete',
    'data discarded'           => 'complete',
    'run stopped early'        => 'complete',
    'qc complete'              => 'complete',
    'run in progress'          => 'update',
         };

  for my $state (keys %{$STATES}) {
    my $family = $STATES->{$state};
    my $xml = sprintf $XML, $state, $family, $state;
    is( $ev->create( { run_status => $state, id_run     => 10,position   => 4, }),1, "$state => $family");
  }
}

{
  my $ev = st::api::event->new({
        util => npg::api::util->new({useragent =>  t::useragent->new({is_success => 1,}),}),
        message       => 'a message',
        eventful_type => 'run',
        eventful_id   => 999,
        family        => 'update',
        identifier    => 100,
        location      => 1,
             });
  $ev->create();
  my $req = $ev->util->useragent->last_request();

  is($req->{Content}, q(<?xml version='1.0'?><event><message>a message</message><eventful_type>run</eventful_type><eventful_id>999</eventful_id><family>update</family><identifier>100</identifier><location>1</location></event>), 'xml generation ok');
}

{
  my $ev = st::api::event->new({
                                util => npg::api::util->new({useragent =>  t::useragent->new({is_success => 0,}),}),
        service       => 'dev',
        message       => 'a message',
        eventful_type => 'run',
        eventful_id   => 999,
        family        => 'update',
             });
  throws_ok { $ev->create();} qr/unable\ to\ update/mix, 'failure to post';
}

1;
