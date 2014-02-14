#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2009-02-05
# Last Modified: $Date: 2012-03-01 10:36:10 +0000 (Thu, 01 Mar 2012) $
# Id:            $Id: 20-view-instrument_utilisation.t 15277 2012-03-01 10:36:10Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/20-view-instrument_utilisation.t $
#
use strict;
use warnings;
use Test::More tests => 7;
use English qw(-no_match_vars);
use t::util;
use t::request;
use npg::model::instrument_utilisation;
use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 15277 $ =~ /(\d+)/mx; $r; };

use_ok('npg::view::instrument_utilisation');
my $util = t::util->new({ fixtures => 1, cgi => CGI->new() });
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
  my $model = npg::model::instrument_utilisation->new({ util => $util });
  my $view  = npg::view::instrument_utilisation->new({
    util => $util,
    model => $model,
    action => q{create},
    aspect => q{}
  });
  my $render;
  eval { $render = $view->render(); };
  like($EVAL_ERROR, qr{You\ \(public\)\ are\ not\ authorised\ for\ this\ view}, 'croaked as not legitimate to create');
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
  ok($util->test_rendered($str, 't/data/rendered/instrument_utilisation/create.xml'), 'pipeline create ok');
}

{
  my $str = t::request->new({
            PATH_INFO      => '/instrument_utilisation',
            REQUEST_METHOD => 'GET',
            username       => 'joe_public',
            util           => $util,
           });

  ok($util->test_rendered($str, 't/data/rendered/instrument_utilisation/list.html'), 'table list view ok');
}

{
  my $str = t::request->new({
            PATH_INFO      => '/instrument_utilisation/graphical',
            REQUEST_METHOD => 'GET',
            username       => 'joe_public',
            util           => $util,
           });
  ok($util->test_rendered($str, 't/data/rendered/instrument_utilisation/list_graphical.html'), 'graphical list view ok');
}

{
  my $str = t::request->new({
            PATH_INFO      => '/instrument_utilisation/text90',
            REQUEST_METHOD => 'GET',
            username       => 'joe_public',
            util           => $util,
           });
  ok($util->test_rendered($str, 't/data/rendered/instrument_utilisation/list.html'), '90 days table list view ok');
}


{
  my $str = t::request->new({
            PATH_INFO      => '/instrument_utilisation/graphical/line90',
            REQUEST_METHOD => 'GET',
            username       => 'joe_public',
            util           => $util,
           });

  ok($util->test_rendered($str, 't/data/rendered/instrument_utilisation/list_graphical_90days.html'), 'graphical list view ok');
}

1;
