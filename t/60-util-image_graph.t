use strict;
use warnings;
use English qw{-no_match_vars};
use Test::More tests => 22;
use Digest::MD5;

my $md5_object = Digest::MD5->new();

use_ok('npg::util::image::graph');

{
  my $graph = npg::util::image::graph->new({});
  isa_ok($graph, 'npg::util::image::graph', '$graph');
  my $args = {
    'width'        => 400,
    'height'       => 200,
    'title'        => 'test data',
    'x_labels_vertical' => 1,
    'x_label'      => 'Run ID',
    'y_label'      => 'PF Yield (GBases)',

  };
  my $data = [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9]];
  my $png;

  eval { $png = $graph->plotter($data, $args, q{lines}, 1); };
  is($EVAL_ERROR, q{}, 'no croak on generation of png graph image - with array rotate');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{ae8d9104d87599a4353477dc32cc3347}, 'md5 hex digest of png is correct');

  eval { $png = $graph->plotter($data, $args, q{lines}, undef); };
  is($EVAL_ERROR, q{}, 'no croak on generation of png graph image - without array rotate');
  $md5_object->add($png);

  is($md5_object->hexdigest(), q{a0f32c37bce83bd58c42182df45971ce}, 'md5 hex digest of png is correct');
}
{
  my $graph = npg::util::image::graph->new({});
  isa_ok($graph, 'npg::util::image::graph', '$graph');
  my $args = {
    'title'        => 'test data',
    'x_labels_vertical' => 1,
    'x_label'      => 'Run ID',
    'y_label'      => 'PF Yield (GBases)',
    'legend'       => ['test_1','test_2'],

  };
  my $data = [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[1,2,3,4,5,6,7,8,9,10]];
  my $png;

  eval { $png = $graph->plotter($data, $args, q{lines}, 1); };
  is($EVAL_ERROR, q{}, 'no croak on generation of png graph image - with legend');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{9cd11c5d83808e707a1cbbb2e72487ce}, 'md5 hex digest of png is correct');
}
{
  my $graph = npg::util::image::graph->new({});
  isa_ok($graph, 'npg::util::image::graph', '$graph');
  my $args = {
    'title'        => 'test data',
    'x_labels_vertical' => 1,
    'x_label'      => 'Run ID',
    'y_label'      => 'PF Yield (GBases)',
    'legend'       => ['test_1','test_2'],

  };
  my $data = [[1,2,3,4,5,6,7,8,9,10],[11,12,13,14,15,14,13,12,15,9],[1,2,3,4,5,6,7,8,9,10]];
  my $png;

  eval { $png = $graph->plotter($data); };
  is($EVAL_ERROR, q{}, 'no croak on generation of png graph image - just data');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{4515cf32770bc5628c8cb943669f36b4}, 'md5 hex digest of png is correct');

  eval { $png = $graph->plotter($data, undef, undef, 1); };
  is($EVAL_ERROR, q{}, 'no croak on generation of png graph image - just data and rotate');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{6580c0fef223fe213c1d411eeff1ab2e}, 'md5 hex digest of png is correct');
}
{
  my $graph = npg::util::image::graph->new({});
  isa_ok($graph, 'npg::util::image::graph', '$graph');
  my $args = {
    'title'        => 'test data',
    'x_labels_vertical' => 1,
    'x_label'      => 'Run ID',
    'y_label'      => 'PF Yield (GBases)',
    'legend'       => ['test_1','test_2'],

  };
  my $data = [];
  my $png;

  eval { $png = $graph->plotter($data, undef, undef, 1); };
  is($EVAL_ERROR, q{}, 'no croak on generation of png graph image - no scalar@{$data}');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{14798143a22d510c6ef786a6450ee405}, 'md5 hex digest of png is correct');
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
  is($EVAL_ERROR, q{}, 'no croak on generation of png graph image');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{f178977b90823fb0f59362191990f185}, 'md5 hex digest of png is correct');

  my $png2;
  $graph->colours([qw(white red)]);
  $data = [[qw(IL1 IL2 IL3 IL4 IL5)],[5,10,15,20,25]];
  eval { $png2 = $graph->plotter($data, $args, q{bars}, 1); };
  is($EVAL_ERROR, q{}, 'no croak on generation of png graph image');
  $md5_object->add($png2);
  is($md5_object->hexdigest(), q{ff6a950d2cb963d615f67cc1673a60db}, 'md5 hex digest of png is correct');
}
