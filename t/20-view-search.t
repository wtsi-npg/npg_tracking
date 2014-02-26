#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2008-01
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 20-view-search.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/20-view-search.t $
#
use strict;
use warnings;
use Test::More tests => 4;
use t::util;
use t::request;
use npg::model::search;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

use_ok('npg::view::search');

my $util = t::util->new({
       fixtures => 1,
      });

{
  my $str = t::request->new({
                             PATH_INFO      => '/search',
                             REQUEST_METHOD => 'GET',
           username       => 'public',
                             util           => $util,
           cgi_params     => {
            query => 'TriosP',
                 },
                            });
  ok($util->test_rendered($str, 't/data/rendered/search.html'), 'list render');
}

{
  my $str = t::request->new({
                             PATH_INFO      => '/search',
                             REQUEST_METHOD => 'GET',
           username       => 'public',
                             util           => $util,
           cgi_params     => {
            query => '  TriosP',
                 },
                            });
  ok($util->test_rendered($str, 't/data/rendered/search.html'), 'list render leading whitespace');
}

{
  my $str = t::request->new({
                             PATH_INFO      => '/search',
                             REQUEST_METHOD => 'GET',
           username       => 'public',
                             util           => $util,
           cgi_params     => {
            query => 'TriosP ',
                 },
                            });
  ok($util->test_rendered($str, 't/data/rendered/search.html'), 'list render trailing whitespace');
}

1;