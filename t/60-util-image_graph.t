use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;

use_ok('npg::util::image::graph');
use_ok('npg::util::image::heatmap');
use_ok('npg::util::image::image_map');
use_ok('npg::util::image::merge');
use_ok('npg::util::image::scale');

lives_ok {npg::util::image::graph->new()->simple_image} 'simple image generated';

1;
