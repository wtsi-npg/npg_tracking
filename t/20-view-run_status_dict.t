#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 20-view-run_status_dict.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/20-view-run_status_dict.t $
#
use strict;
use warnings;
use Test::More tests => 2;
use t::util;
use t::request;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

my $util = t::util->new({fixtures => 1});

{
  my $str = t::request->new({
			     util           => $util,
			     username       => 'public',
			     REQUEST_METHOD => 'GET',
			     PATH_INFO      => '/run_status_dict.xml',
			    });
  $str =~ s/.*?\n\n//smx;
  ok($util->test_rendered($str, 't/data/rendered/run_status_dict.xml'), 'run_status_dict list_xml');
}

{
  my $str = t::request->new({
			     util           => $util,
			     username       => 'public',
			     REQUEST_METHOD => 'GET',
			     PATH_INFO      => '/run_status_dict/2.xml',
			    });

  $str =~ s/.*?\n\n//smx;
  ok($util->test_rendered($str, 't/data/rendered/run_status_dict/2.xml'), 'run_status_dict read_xml');
}
