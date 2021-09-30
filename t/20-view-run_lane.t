use strict;
use warnings;
use Test::More tests => 4;
use t::request;
use t::util;
use npg::model::run_lane;

use_ok('npg::view::run_lane');

my $util = t::util->new({
       fixtures => 1,
      });

{
  my $run_lane = npg::model::run_lane->new({
              util        => $util,
              id_run_lane => 16,
             });
  my $view = npg::view::run_lane->new({
               model  => $run_lane,
               aspect => 'read',
               util   => $util,
              });
  isa_ok($view, 'npg::view::run_lane');
}

{
  for my $aspect (qw(update_tags)) {
    my $str = t::request->new({
             PATH_INFO      => "/run_lane/16;$aspect",
             REQUEST_METHOD => 'POST',
             username       => q[joe_annotator],
             util           => $util,
            });
    unlike($str, qr/not\ authorised/mix, "annotator $aspect authorised");

    my $str2 = t::request->new({
        PATH_INFO      => "/run_lane/16;$aspect",
        REQUEST_METHOD => 'POST',
        username       => q[public],
        util           => $util,
             });
    like($str2, qr/not\ authorised/mix, "public $aspect not authorised");
  }
}

1;
