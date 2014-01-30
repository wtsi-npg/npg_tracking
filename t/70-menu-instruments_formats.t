#########
# Author:        mg8
# Maintainer:    $Author: mg8 $
# Created:       28 July 2009
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 70-menu-instruments_formats.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/70-menu-instruments_formats.t $
#
use strict;
use warnings;
use Test::More tests => 1;
use t::util;
use t::request;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

my $util = t::util->new({ fixtures => 1, cgi => CGI->new() });
{
  my $str = t::request->new({
           PATH_INFO      => '/instrument_format',
           REQUEST_METHOD => 'GET',
           username       => 'public',
           util           => $util,
          });
  ok($util->test_rendered($str,  't/data/rendered/menus/instruments_formats.html'), 'menu instruments>formats');
}
