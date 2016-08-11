use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use t::util;
use t::request;

use_ok('npg::model::instrument_utilisation');
use_ok('npg::view::instrument_utilisation');

my $util = t::util->new({ fixtures => 1});

{
  my $cgi = $util->cgi();
  $cgi->param( q{pipeline}, q{1} );
  $cgi->param( q{date}, q{2009-02-02 00:00:00} );
  $cgi->param( q{total_insts}, q{9} );
  $cgi->param( q{perc_utilisation_total_insts}, q{0.00});
  $cgi->param( q{perc_uptime_total_insts}, q{44.44} );
  $cgi->param( q{official_insts}, q{6} );
  $cgi->param( q{perc_utilisation_official_insts}, q{0.00} );
  $cgi->param( q{perc_uptime_official_insts}, q{50.00} );
  $cgi->param( q{prod_insts}, q{8} );
  $cgi->param( q{perc_utilisation_prod_insts}, q{0.00} );
  $cgi->param( q{perc_uptime_prod_insts}, q{50.00} );
  $cgi->param( q{id_instrument_format}, q{10} );

  my $view  = npg::view::instrument_utilisation->new({
    util => $util,
    model =>  npg::model::instrument_utilisation->new({ util => $util }),
    action => q{create},
    aspect => q{}
  });
  throws_ok { $view->render(); } qr{You\ \(public\)\ are\ not\ authorised\ for\ this\ view},
    'croaked as not legitimate to create';
}
{
  my $str  = t::request->new({
            PATH_INFO      => '/instrument_utilisation.xml',
            REQUEST_METHOD => 'POST',
            username       => 'pipeline',
            util           => $util,
            cgi_params     => {
                 pipeline =>      '1',
                 date =>      '2009-02-02 00:00:00',
                 total_insts =>      '9',
                 perc_utilisation_total_insts =>      '0.00',
                 perc_uptime_total_insts =>      '44.44',
                 official_insts =>      '6',
                 perc_utilisation_official_insts =>      '0.00',
                 perc_uptime_official_insts =>      '50.00',
                 prod_insts =>      '8',
                 perc_utilisation_prod_insts =>     '0.00',
                 perc_uptime_prod_insts => '50.00',
                 id_instrument_format => q{10},
            },
           });
  ok($util->test_rendered($str, 't/data/rendered/instrument_utilisation/create.xml'),
    'pipeline create ok');
}

1;
