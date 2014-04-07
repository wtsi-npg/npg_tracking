use strict;
use warnings;
use Test::More tests => 29;
use Test::Deep;

use_ok('npg::api::instrument', 'use ok');

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/npg_api';

{
  my $instrument1 = npg::api::instrument->new();
  isa_ok($instrument1, 'npg::api::instrument', 'constructs ok');
  is($instrument1->id_instrument(), undef, 'undef default id');
}

{
  my $instrument2 = npg::api::instrument->new({'id_instrument'=>1});
  isa_ok($instrument2, 'npg::api::instrument', 'constructs ok with args');
  is($instrument2->id_instrument(), 1, 'id set correctly by constructor');
  is($instrument2->id_instrument(999), 999, 'id set correctly by accessor');
}

{
  my $instrument = npg::api::instrument->new({'id_instrument' => 1,});
  my $instruments = $instrument->instruments();
  isa_ok($instruments, 'ARRAY', 'list of instruments obtained ok');
  is(scalar @{$instruments}, 13, 'correct number of instruments');
  
  my $inst = $instruments->[12];
  is($inst->name(), 'IL13', 'correct instrument obtained');
  isa_ok($inst->{designations}, 'ARRAY', 'list of designations obtained via list');
  my $desig = $inst->designations()->[0];
  is($desig->description(), 'Hot spare', 'designation description obtained ok');
  $desig = $inst->designations()->[1];
  is($desig->description(), 'Accepted', 'designation description obtained ok');

  my $runs = $instrument->runs();
  is(scalar @{$runs}, 13, 'correct number of runs');
  is($runs->[0]->id_instrument(), 6, 'run->id_instrument');

  my $cis = $instrument->current_instrument_status();
  is($cis->util, $instrument->util);
  is($cis->util, $cis->instrument->util);

  is($cis->date(), "2007-09-19 13:09:42", 'attrs ok for current status');
  is($cis->id_instrument(), 1, 'cis id_instrument');
  is($cis->instrument->id_instrument(), 1, 'cis -> instrument id_instrument');

  my $ciss = $instrument->instrument_statuses();
  is(scalar @{$ciss}, 1, 'correct number of statuses');

  is($cis->id_instrument_status(), $ciss->[0]->id_instrument_status(), 'current_ins_stat == instrument_statuses->[n]');

  my $cisi = $cis->instrument();
  isa_ok($cisi, 'npg::api::instrument', 'instrument type');

  is($cisi->id_instrument(), $instrument->id_instrument(), 'ids match between instrument and instrument_status->instrument');

  my $instrument3 = npg::api::instrument->new( { 'id_instrument' => 24, } );

  my $computer       = $instrument3->instrument_comp();
  my $mirroring_host = $instrument3->mirroring_host();
  my $designation    = $instrument3->designations();
  my $staging_dir    = $instrument3->staging_dir();
  my $ip_address     = $instrument3->ipaddr();

  is( $ip_address,       '192.168.255.26',         'ip address matches' );
  is( $computer,         'il21win',                'computer name matches' );
  is( $staging_dir,      '/staging/IL21/incoming', 'staging directory matches' );
  is( $mirroring_host,   'sf-1-1-06',              'mirroring host matches' );
  cmp_bag( $designation, ['Hot spare'],            'retrieve a single designation' );

  my $instrument4 = npg::api::instrument->new( { 'id_instrument' => 36, } );
  $designation = $instrument4->designations();
  cmp_bag( $designation, [ 'R&D', 'Hot spare' ], 'retrieve multiple designations' );
}

1;
