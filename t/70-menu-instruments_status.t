#########
# Author:        mg8
# Maintainer:    $Author: mg8 $
# Created:       28 July 2009
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 70-menu-instruments_status.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/70-menu-instruments_status.t $
#
use strict;
use warnings;
use Test::More tests => 2;
use t::util;
use npg::model::instrument;
use CGI;
use t::request;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

my $util = t::util->new({
       fixtures => 1,
      });


{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument;list_graphical',
           username       => 'public',
           util           => $util,
          });

  ok($util->test_rendered($str, 't/data/rendered/menus/instruments_status_graphical.html'), 'menu instruments>status>graphical');
}


{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument;list_textual',
           username       => 'public',
           util           => $util,
          });

  ok($util->test_rendered($str, 't/data/rendered/menus/instruments_status_textual.html'), 'menu instruments>status>textual');
}

1;