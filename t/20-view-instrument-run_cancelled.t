#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2013-01-23 16:49:39 +0000 (Wed, 23 Jan 2013) $
# Id:            $Id: 20-view-instrument-run_cancelled.t 16549 2013-01-23 16:49:39Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/20-view-instrument-run_cancelled.t $
#

use strict;
use warnings;
use Test::More tests => 3;
use t::util;
use t::request;
use npg::view::instrument;

my $util = t::util->new( { fixtures => 1 } );

$util->requestor('joe_loader');

my $inst = npg::model::instrument->new({
          util => $util,
          name => 'IL8',
               });
{
  #########
  # set up a cancelled run
  #
  my $run = npg::model::run->new({
          util                 => $util,
          id_instrument        => $inst->id_instrument(),
          batch_id             => 2690,
          expected_cycle_count => 0,
          actual_cycle_count   => 0,
          priority             => 0,
          id_user              => $util->requestor->id_user(),
          is_paired            => 1,
          team                 => 'A',
         });
  $run->create();

  my $rsd = npg::model::run_status_dict->new({
                util        => $util,
                description => 'run cancelled',
               });

  my $status_update = t::request->new({
               REQUEST_METHOD => 'POST',
               PATH_INFO      => '/run_status/',
               username       => 'joe_loader',
               util           => $util,
               cgi_params     => {
               id_run             => $run->id_run(),
               id_run_status_dict => $rsd->id_run_status_dict(),
               },
              });

  my $png = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/IL8.png',
           username       => 'public',
           util           => $util,
          });

  t::util::is_colour($png, $npg::view::instrument::COLOUR_YELLOW, 'run cancelled + unwashed = status yellow');
}

{
  #########
  # wash the instrument
  #
  my $isd = npg::model::instrument_status_dict->new({
                 util        => $util,
                 description => 'wash in progress',
                });
  my $status_update = t::request->new({
               REQUEST_METHOD => 'POST',
               PATH_INFO      => '/instrument_status/',
               username       => 'joe_admin',
               util           => $util,
               cgi_params     => {
                id_instrument             => $inst->id_instrument(),
                id_instrument_status_dict => $isd->id_instrument_status_dict(),
               },
              });

  my $png = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/IL8.png',
           username       => 'public',
           util           => $util,
          });

  t::util::is_colour($png, $npg::view::instrument::COLOUR_YELLOW, 'run cancelled + startedwash = status yellow');


  $isd = npg::model::instrument_status_dict->new({
                 util        => $util,
                 description => 'wash performed',
                });
  $status_update = t::request->new({
               REQUEST_METHOD => 'POST',
               PATH_INFO      => '/instrument_status/',
               username       => 'joe_admin',
               util           => $util,
               cgi_params     => {
                id_instrument             => $inst->id_instrument(),
                id_instrument_status_dict => $isd->id_instrument_status_dict(),
               },
              });

  $png = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/IL8.png',
           username       => 'public',
           util           => $util,
          });

  t::util::is_colour( $png, $npg::view::instrument::COLOUR_BLUE,
                           'run cancelled + washed = status blue' );
}
