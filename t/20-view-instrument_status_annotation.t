use strict;
use warnings;
use Test::More tests => 2;
use t::util;
use t::request;
use npg::model::instrument_status;

use_ok('npg::view::instrument_status_annotation');

my $util = t::util->new({fixtures => 1});

{
  my $str = t::request->new({
           PATH_INFO      => '/instrument_status_annotation/;add_ajax',
           REQUEST_METHOD => 'GET',
           username       => 'joe_annotator',
           util           => $util,
           cgi_params     => {
            id_instrument_status => 1,
                 },
          });
  ok($util->test_rendered($str, 't/data/rendered/instrument_status_annotation;add-ajax.html'), 'render of add_ajax ok for current instrument status annotation');
}

1;
