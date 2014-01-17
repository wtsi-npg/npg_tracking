#########
# Author:        mg8
# Maintainer:    $Author: dj3 $
# Created:       28 July 2009
# Last Modified: $Date: 2012-01-30 14:59:22 +0000 (Mon, 30 Jan 2012) $
# Id:            $Id: 70-menu-instruments_make_change.t 15060 2012-01-30 14:59:22Z dj3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/70-menu-instruments_make_change.t $
#
use strict;
use warnings;
use Test::More tests => 3;
use t::util;
use t::request;
use npg::model::instrument_mod;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 15060 $ =~ /(\d+)/mx; $r; };

use_ok('npg::view::instrument_mod');
my $util = t::util->new({ fixtures => 1, cgi => CGI->new() });
{
  $util->requestor(q(joe_loader));

  my $view = npg::view::instrument_mod->new({
               util   => $util,
               action => 'list',
               aspect => q{},
               model  => npg::model::instrument_mod->new({
                      util => $util,
                           }),
              });
  my $render;
  eval { $render = $view->render(); };
  
  ok($util->test_rendered($render, 't/data/rendered/menus/instruments_make_change_mods.html'), 'menu instruments>make_change>mods');
}


{
  my $str = t::request->new({
           PATH_INFO      => '/instrument/edit_statuses',
           REQUEST_METHOD => 'GET',
           username       => 'joe_loader',
           util           => $util,
          });

  ok($util->test_rendered($str,  't/data/rendered/menus/instruments_make_change_statuses.html'), 'menu instruments>make_change>edit_statuses');
}
