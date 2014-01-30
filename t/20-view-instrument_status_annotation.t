#########
# Author:        gq1
# Maintainer:    $Author: mg8 $
# Created:       2010-04-27
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 20-view-instrument_status_annotation.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/20-view-instrument_status_annotation.t $
#
use strict;
use warnings;
use Test::More tests => 2;
use t::util;
use t::request;
use npg::model::instrument_status;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

use_ok('npg::view::instrument_status_annotation');

my $util = t::util->new({fixtures => 1});

{
  my $str = t::request->new({
           PATH_INFO      => '/instrument_status_annotation/;add_ajax',
           REQUEST_METHOD => 'GET',
           username       => 'joe_annotator',
           util           => $util,
           cgi_params     => {
            id_instrument_status => 1,
                 },
          });
  ok($util->test_rendered($str, 't/data/rendered/instrument_status_annotation;add-ajax.html'), 'render of add_ajax ok for current instrument status annotation');
}

1;
