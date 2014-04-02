use strict;
use warnings;
use English qw{-no_match_vars};
use Test::More tests => 18;
use Digest::MD5;
use npg::util::image::graph;

my $md5_object = Digest::MD5->new();

use_ok('npg::util::image::merge');

{
  my $merge = npg::util::image::merge->new({});
  isa_ok($merge, 'npg::util::image::merge', '$merge');
  my $arg_refs = {
     format => 'spamcodjfijdijcvdocv',
 };
  eval { $merge->merge_images($arg_refs); };
  like($EVAL_ERROR, qr{spamcodjfijdijcvdocv\ is\ not\ a\ supported\ format\ of\ merged\ images}, 'croaked on running $merge->merge_images() as unsupported format');
}
{
  my $merge = npg::util::image::merge->new({});
  my $arg_refs = {
     format => 'table_portrait',
 };
  eval { $merge->merge_images($arg_refs); };
  like($EVAL_ERROR, qr{no\ data\ provided\ for\ drawing\ images}, 'croaked on running $merge->merge_images() as no data provided');
}
{
  my $merge = npg::util::image::merge->new({});
  my $arg_refs = {
     format => 'table_portrait',
     data   => [],
 };
  eval { $merge->merge_images($arg_refs); };
  like($EVAL_ERROR, qr{no\ data\ provided\ for\ drawing\ images}, 'croaked on running $merge->merge_images() as no column data provided');
}
{
  my $merge = npg::util::image::merge->new({});
  my $arg_refs = {
    format => 'table_portrait',
    rows   => '8',
    cols   => '3',
    data   => [
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[521,522,923,524,55,524,513,512,515,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ],
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ],
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[521,522,923,524,55,524,513,512,515,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ],
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ],
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[521,522,923,524,55,524,513,512,515,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ],
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ],
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[521,522,923,524,55,524,513,512,515,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ],
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ]
    ],
    column_headings => ['Lane', 'All', 'Call', '% Base Calls'],
    y_min_values => [0,0,0],
    y_max_values => [1500,1500,undef],
    
    row_headings => [qw(1 2 3 4 5 6 7 8)],
    args_for_image => {
      'width'        => 126,
      'height'       => 84,
      'x_labels_vertical' => 1,
    },
  };
  my $png;
  eval { $png = $merge->merge_images($arg_refs); };
  is($EVAL_ERROR, q{}, 'no croak on running $merge->merge_images()');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{7ed893f3c5d7807c43448e567744c6c4}, 'md5 hex digest of png is correct');
}
{
  my $merge = npg::util::image::merge->new({});
  my $arg_refs = {
    format => 'table_landscape',
    rows   => '3',
    cols   => '8',
    data   => [
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[521,522,923,524,55,524,513,512,515,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[521,522,923,524,55,524,513,512,515,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[521,522,923,524,55,524,513,512,515,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ],
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[521,522,923,524,55,524,513,512,515,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[521,522,923,524,55,524,513,512,515,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ],
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[521,522,923,524,55,524,513,512,515,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[521,522,923,524,55,524,513,512,515,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[521,522,923,524,55,524,513,512,515,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ],
    ],
    row_headings => ['All', 'Call', '% Base Calls'],
    y_min_values => [0,0,0],
    y_max_values => [1500,1500,undef],
    
    column_headings => [qw(Lane 1 2 3 4 5 6 7 8)],
    args_for_image => {
      'width'        => 126,
      'height'       => 84,
      'x_labels_vertical' => 1,
    },
  };
  my $png;
  eval { $png = $merge->merge_images($arg_refs); };
  is($EVAL_ERROR, q{}, 'no croak on running $merge->merge_images()');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{b4a03c7025ee7d631da7d4b57752f04a}, 'md5 hex digest of png is correct');
}
{
  my $graph = npg::util::image::graph->new({});
  isa_ok($graph, 'npg::util::image::graph', '$graph');
  $graph->colours([qw(red white)]);
  my $args = {
    'x_label'      => 'Instrument',
    'y_label'      => 'Days',
    'y_max_value'  => 50,
    'y_min_value'  => 0,

  };
  my $data = [[qw(IL1 IL2 IL3 IL4 IL5)],[10,20,30,40,50]];
  my $png;

  eval { $png = $graph->plotter($data, $args, q{bars}, 1); };
  my $png2;
  $graph->colours([qw(white red)]);
  $data = [[qw(IL1 IL2 IL3 IL4 IL5)],[5,10,15,20,25]];
  eval { $png2 = $graph->plotter($data, $args, q{bars}, 1); };

  my $merge = npg::util::image::merge->new({});

  my $arg_refs = {
    format => 'overlay_all_images_exactly',
    images => [$png, $png2],
  };
  my $result_png;
  eval { $result_png = $merge->merge_images($arg_refs); };
  is($EVAL_ERROR, q{}, 'no croak on running $merge->merge_images()');
  $md5_object->add($result_png);
  is($md5_object->hexdigest(), q{0050d9ff38d06b335a6c2bddf58034d1}, 'md5 hex digest of result_png is correct');
  
}

{
  my $merge = npg::util::image::merge->new({});

  my $arg_refs = {
    format => 'gantt_chart_vertical',
    'x_label'      => 'Instrument',
    'y_label'      => 'Days',
    'y_max_value'  => 50,
    'y_min_value'  => 0,
    'x_axis'       => [qw(IL2 IL3 IL4 IL5 IL6)],
    'data_points'  => [[50,20,30,40,50],[5,10,15,20,25],[0,0,10,18,0],[0,0,5,0,0]],
    'height'       => 400,
    'width'        => 800,
    'y_tick_number' => 5,
  };
  my $result_png;
  eval { $result_png = $merge->merge_images($arg_refs); };
  is($EVAL_ERROR, q{}, 'no croak on running $merge->merge_images()');
  $md5_object->add($result_png);
  # a new version of libpng seems to cause these to be slightly different (even though the image looks the same) so to cope with possible
  # versions underlying GD, have put the possible md5sums into a hash, and then test if the hash key exists
  my %correct_possible_md5sums = (
    q{b8935ec19ac305602276806e1409ec93} => 1,
    q{0f194b3c9476e557d80b4c7da480061f} => 1,
  );
  ok($correct_possible_md5sums{$md5_object->hexdigest()}, 'md5 hex digest of result_png is correct');
}
{
  my $merge = npg::util::image::merge->new({});

  my $arg_refs = {
    format => 'gantt_chart_vertical',
    'x_label'      => 'Instrument',
    'y_label'      => 'Days',
    'y_max_value'  => 50,
    'y_min_value'  => 0,
    'x_axis'       => [qw(IL2 IL3 IL4 IL5 IL6)],
    'data_points'  => [[50,20,30,40,50],[5,10,15,20,25],[0,0,10,18,0],[0,0,5,0,0]],
    'add_points'   => [[45,15,25,0,0],[undef,undef,15,0,undef],[undef,undef,10,0,1]],
    'height'       => 400,
    'width'        => 800,
    'y_tick_number' => 5,
  };
  my $result_png;
  eval { $result_png = $merge->merge_images($arg_refs); };
  is($EVAL_ERROR, q{}, 'no croak on running $merge->merge_images()');
  $md5_object->add($result_png);
  my %correct_possible_md5sums = (
    q{dd24ffe504dd4b6404003826c09d22e5} => 1,
    q{3eeb9b901dc468d2612bf188a4f0c509} => 1,
  );
  ok($correct_possible_md5sums{$md5_object->hexdigest()}, 'md5 hex digest of result_png is correct');
}
{
  my $merge = npg::util::image::merge->new({});

  my $arg_refs = {
    format => 'gantt_chart_vertical',
    'x_label'      => 'Instrument',
    'y_label'      => 'Days',
    'y_max_value'  => 50,
    'y_min_value'  => 0,
    'x_axis'       => [qw(IL2 IL3 IL4 IL5 IL6)],
    'data_points'  => [[50,20,30,40,50],[5,10,15,20,25],[0,0,10,18,0],[0,0,5,0,0]],
    'add_points'   => [[45,15,25,0,0],[undef,undef,15,0,undef],[undef,undef,10,0,1]],
    'height'       => 400,
    'width'        => 800,
    'colour_of_block' => q{black},
    'y_tick_number' => 5,
  };
  my $result_png;
  eval { $result_png = $merge->merge_images($arg_refs); };
  is($EVAL_ERROR, q{}, 'no croak on running $merge->merge_images()');
  $md5_object->add($result_png);
  my %correct_possible_md5sums = (
    q{102c622e6db01ff67c132379b7f570bf} => 1,
    q{3a838fd2d98396353efcb9b65ff14551} => 1,
  );
  ok($correct_possible_md5sums{$md5_object->hexdigest()}, 'md5 hex digest of result_png is correct');

}
__END__  
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ],
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[521,522,923,524,55,524,513,512,515,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ],
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ],
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[521,522,923,524,55,524,513,512,515,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ],
    [
    [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]],[[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]]
    ]
