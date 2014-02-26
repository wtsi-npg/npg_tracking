#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-03-08 11:21:27 +0000 (Thu, 08 Mar 2012) $
# Id:            $Id: 20-view-instrument-run_pending.t 15308 2012-03-08 11:21:27Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/20-view-instrument-run_pending.t $
#

use strict;
use warnings;
use Test::More tests => 1;
use t::util;
use t::request;
use npg::view::instrument;

my $util = t::util->new({fixtures=>1});

{
  $util->requestor('joe_loader');

  my $inst = npg::model::instrument->new({
					  util => $util,
					  name => 'IL29',
					 });
  my $run = npg::model::run->new({
				  util                 => $util,
				  id_instrument        => $inst->id_instrument(),
				  batch_id             => 2690,
				  id_run_pair          => 3,
				  expected_cycle_count => 0,
				  actual_cycle_count   => 0,
				  priority             => 0,
				  id_user              => $util->requestor->id_user(),
                                  team                 => 'B',
				 });
  $run->create();

  my $png = t::request->new({
			     REQUEST_METHOD => 'GET',
			     PATH_INFO      => '/instrument/IL29.png',
			     username       => 'public',
			     util           => $util,
			    });

  t::util::is_colour($png, $npg::view::instrument::COLOUR_GREEN, 'run pending = status green');
}
