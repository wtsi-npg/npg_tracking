use strict;
use warnings;
use t::util;
use Test::More tests => 3;

use_ok('npg::model::run');
my $util = t::util->new({fixtures => 0,});

{
  my $run_model = npg::model::run->new({
                                      id_run => 10,
                                      util => $util,
                                    });
  isa_ok($run_model, 'npg::model::run');
  $run_model->{loader_info}->{''} = {loader=>'ajb', date=>'2010-06-11'};
  is($run_model->loader_info()->{loader}, 'ajb', 'Does not fetch anything if loader already cached');
}

1;
