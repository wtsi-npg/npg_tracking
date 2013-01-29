#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-08-07
# Last Modified: $Date: 2013-01-23 16:49:39 +0000 (Wed, 23 Jan 2013) $
# Id:            $Id: 60-util-image_map.t 16549 2013-01-23 16:49:39Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/60-util-image_map.t $
#

use strict;
use warnings;
use English qw{-no_match_vars};
use Test::More tests => 6;
use t::util;

use_ok('npg::util::image::image_map');

my $data = [[0,30,21,51,{position => 1,tile => 50,value => 34.5,}],[22,30,43,51,{position => 1,tile => 51,value => 1.6,}],[46,30,67,51,{position => 2,tile => 50,value => 34.5,}],[68,30,89,51,{position => 2,tile => 51,value => 1.6,}]];

foreach my $box (@{$data}) {
  my $hash = $box->[4];
  my $url = q{/cgi-bin/?id_run=10&position=}. $hash->{position} . q{&tile=} . $hash->{tile};
  $hash->{url} = $url;
}

my $image_map_object = npg::util::image::image_map->new();

isa_ok($image_map_object, 'npg::util::image::image_map', '$image_map_object');

my $new_image_map_object = npg::util::image::image_map->new({});
isa_ok($new_image_map_object, 'npg::util::image::image_map', '$new_image_map_object');
isnt($new_image_map_object, $image_map_object, 'new object created, with hashref sent to it');


my $map;

eval { $map = $image_map_object->render_map({id => 'some_id', data => $data, image_url => 'http://some/url/image'}); };
is($EVAL_ERROR, q{}, 'no croak on create of map');
ok(t::util->new()->test_rendered($map, 't/data/rendered/map.html'), 'map rendered ok');
