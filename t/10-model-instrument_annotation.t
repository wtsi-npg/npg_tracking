use strict;
use warnings;
use t::util;
use Test::More tests => 4;
use npg::model::annotation;
use npg::model::instrument;

use_ok('npg::model::instrument_annotation');

my $util  = t::util->new({
        fixtures  => 1,
       });

{
  my $ia = npg::model::instrument_annotation->new({
               util => $util,
              });
  isa_ok($ia, 'npg::model::instrument_annotation');
}

{
  my $i = npg::model::instrument->new({
               util => $util,
               name => 'IL1',
              });
  my $a = npg::model::annotation->new({
               util    => $util,
               comment => 'test annotation',
               id_user => $util->requestor->id_user(),
              });
  my $ia = npg::model::instrument_annotation->new({
               util          => $util,
               id_instrument => $i->id_instrument(),
               annotation    => $a,
              });
  ok($ia->create(), 'instrument_annotation create');

  my $ia2 = npg::model::instrument_annotation->new({
                util          => $util,
                id_instrument_annotation => $ia->id_instrument_annotation(),
              });
  is($ia2->annotation->comment(), 'test annotation');
}
