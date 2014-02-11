#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-03-11
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 20-view-run_lane-update_tags.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/20-view-run_lane-update_tags.t $
# todo: fixture data & direct tag/database verification
#
use strict;
use warnings;
use Test::More tests => 4;
use t::util;
use t::request;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

my $util = t::util->new({fixtures=>1});

{
  my $str = t::request->new({
           util           => $util,
           username       => 'public',
           REQUEST_METHOD => 'POST',
           PATH_INFO      => '/run_lane/1;update_tags',
          });

  like($str, qr{not\ authorised}smx, 'not authorised to create tags if not admin');
}

{
  my $str = t::request->new({
           util           => $util,
           username       => 'joe_annotator',
           REQUEST_METHOD => 'POST',
           PATH_INFO      => '/run_lane/1;update_tags',
           cgi_params     => {
                 },
          });

  ok($util->test_rendered($str, 't/data/rendered/run_lane/1;update_tags'), 'update tags without tags');
}

{
  my $str = t::request->new({
           util           => $util,
           username       => 'joe_annotator',
           REQUEST_METHOD => 'POST',
           PATH_INFO      => '/run_lane/1;update_tags',
           cgi_params     => {
            tags           => 'good BAd',
            tagged_already => 'good',
                 },
          });

  ok($util->test_rendered($str, 't/data/rendered/run_lane/1;update_tags'), 'update tags with tag addition');
}

{
  my $str = t::request->new({
           util           => $util,
           username       => 'joe_annotator',
           REQUEST_METHOD => 'POST',
           PATH_INFO      => '/run_lane/1;update_tags',
           cgi_params     => {
            tags           => 'good',
            tagged_already => 'good bad',
                 },
          });

  ok($util->test_rendered($str, 't/data/rendered/run_lane/1;update_tags'), 'update tags with tag removal');
}

1;
