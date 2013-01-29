#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 20-view-instrument-no_runs.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/20-view-instrument-no_runs.t $
#

use strict;
use warnings;
use Test::More tests => 1;
use t::util;
use t::request;
use npg::view::instrument;

my $util = t::util->new({fixtures=>1});

{
  my $png = t::request->new({
			     REQUEST_METHOD => 'GET',
			     PATH_INFO      => '/instrument/IL29.png',
			     username       => 'public',
			     util           => $util,
			    });

  t::util::is_colour($png, $npg::view::instrument::COLOUR_YELLOW, 'no runs = status yellow');
}
