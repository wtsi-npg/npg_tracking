#########
# Author:        mg8
# Maintainer:    $Author: mg8 $
# Created:       28 July 2009
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 70-menu-instruments_utilisation.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/70-menu-instruments_utilisation.t $
#
use strict;
use warnings;
use Test::More tests => 6;
use t::util;
use CGI;
use t::request;
use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

use Carp;

my $util = t::util->new({
       fixtures => 1,
      });


{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument_utilisation',
           username       => 'public',
           util           => $util,
          });

  ok($util->test_rendered($str, 't/data/rendered/menus/instruments_utilisation_30days_textual.html'), 'menu instruments>utilisation>30days-textual');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument_utilisation/graphical',
           username       => 'public',
           util           => $util,
          });
  
  ok($util->test_rendered($str, 't/data/rendered/menus/instruments_utilisation_30days_barchart.html'), 'menu instruments>utilisation>30days-barchart');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument_utilisation/graphical/line',
           username       => 'public',
           util           => $util,
          });

  ok($util->test_rendered($str, 't/data/rendered/menus/instruments_utilisation_30days_lineplot.html'), 'menu instruments>utilisation>30days-lineplot');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument_utilisation/text90',
           username       => 'public',
           util           => $util,
          });

  ok($util->test_rendered($str, 't/data/rendered/menus/instruments_utilisation_90days_textual.html'), 'menu instruments>utilisation>90days-textual');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument_utilisation/graphical/line90',
           username       => 'public',
           util           => $util,
          });

  ok($util->test_rendered($str, 't/data/rendered/menus/instruments_utilisation_90days_lineplot.html'), 'menu instruments>utilisation>90days_lineplot');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument_status/graphical',
           username       => 'public',
           util           => $util,
          });

  ok($util->test_rendered($str, 't/data/rendered/menus/instruments_utilisation_uptime.html'), 'menu instruments>utilisation>uptime');
}

