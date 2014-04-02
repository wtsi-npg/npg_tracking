use strict;
use warnings;
use English qw{-no_match_vars};
use Test::More tests => 38;
use Digest::MD5;

my $md5_object = Digest::MD5->new();

use_ok('npg::util::image::heatmap');

{
  my $heatmap = npg::util::image::heatmap->new({
    data_array => [[1..50],[51..100],[101..150],[151..200],[201..250],[251..300],[301..350],[351..400],[1..50],[51..100],[101..150],[151..200],[201..250],[251..300],[301..350],[351..400]],
  });
  isa_ok($heatmap, 'npg::util::image::heatmap', '$heatmap');

  my $png;
  eval { $png = $heatmap->plot_illumina_map({tiles_per_lane => 100}); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, 400 different values, GA2 chip');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{2d712e5aa72da173b69091ec24144383}, 'md5 hex digest of png is correct');
}

{
  my $heatmap = npg::util::image::heatmap->new({
    data_array     => [[1..50],[51..100],[101..150],[151..200],[151..200],[1..50],[101..150],[51..100],[1..50],[51..100],[101..150],[151..200],[151..200],[1..50],[101..150],[51..100]],
    tiles_per_lane => 100,
  });

  my $png;
  eval { $png = $heatmap->plot_illumina_map(); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, 200 different values, GA2 chip');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{7ae551ad18227ac54e7007c2be46a72a}, 'md5 hex digest of png is correct');
}

{
  my $heatmap = npg::util::image::heatmap->new({
    data_array => [
      [1..110],[111..220],[221..330],[1..110],[111..220],[221..330],
      [1..110],[111..220],[221..330],[1..110],[111..220],[221..330],
      [1..110],[111..220],[221..330],[1..110],[111..220],[221..330],
      [1..110],[111..220],[221..330],[1..110],[111..220],[221..330]
    ],
  });

  my $png;
  eval { $png = $heatmap->plot_illumina_map({tiles_per_lane => 330}); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, 330 different values, GA1 chip');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{efd70ca16c5faaa687f4a3aca7666a71}, 'md5 hex digest of png is correct');
}

{
  my $non_integer_array = [qw(
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
  )];
  my $heatmap = npg::util::image::heatmap->new({
    data_array => [
      $non_integer_array,$non_integer_array,$non_integer_array,$non_integer_array,$non_integer_array,$non_integer_array,
      $non_integer_array,$non_integer_array,$non_integer_array,$non_integer_array,$non_integer_array,$non_integer_array,
      $non_integer_array,$non_integer_array,$non_integer_array,$non_integer_array,$non_integer_array,$non_integer_array,
      $non_integer_array,$non_integer_array,$non_integer_array,$non_integer_array,$non_integer_array,$non_integer_array,
    ],
    tiles_per_lane => 330,
  });

  my $png;
  eval { $png = $heatmap->plot_illumina_map(); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, 330 different floating point values, GA1 chip');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{c05df108a8e94ac510d75dd8425770de}, 'md5 hex digest of png is correct');
}

{
  my $non_integer_array_first = [qw(
    10 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6
    8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2
  )];
  my $non_integer_array = [qw(
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6
    8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2
  )];
  my $heatmap = npg::util::image::heatmap->new({
    data_array => [
      [@{$non_integer_array_first}],[@{$non_integer_array}],
      [@{$non_integer_array}],[@{$non_integer_array}],
      [@{$non_integer_array}],[@{$non_integer_array}],
      [@{$non_integer_array}],[@{$non_integer_array}]
    ],
    tiles_per_lane => 330,
  });

  my $png;
  eval { $png = $heatmap->plot_illumina_map(); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, 330 different values, GA1 chip, where only an array of all tiles per lane is provided');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{444f1926503acc37b9ebe6576b74430a}, 'md5 hex digest of png is correct');
}

{
  my $non_integer_array_first = [qw(
    10 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
  )];
  my $non_integer_array = [qw(
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
  )];
  my $heatmap = npg::util::image::heatmap->new({
    data_array => [
      [@{$non_integer_array_first}],[@{$non_integer_array}],
      [@{$non_integer_array}],[@{$non_integer_array}],
      [@{$non_integer_array}],[@{$non_integer_array}],
      [@{$non_integer_array}],[@{$non_integer_array}]
    ],
    tiles_per_lane => 100,
  });

  my $png;
  eval { $png = $heatmap->plot_illumina_map(); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, 100 different values, GA2 chip, where only an array of all tiles per lane is provided');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{ac8b5462ffb55264c4319e57563daac2}, 'md5 hex digest of png is correct');
}

{
  my $non_integer_array = [qw(
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
  )];
  my $non_integer_array_first = [qw(
    10 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
  )];
  my $heatmap = npg::util::image::heatmap->new({
    data_array => [
      [@{$non_integer_array_first}],[@{$non_integer_array}],
      [@{$non_integer_array}],[@{$non_integer_array}],
      [@{$non_integer_array}],[@{$non_integer_array}],
      [@{$non_integer_array}],[@{$non_integer_array}]
    ],
    tiles_per_lane => 100,
  });

  my $png;
  eval { $png = $heatmap->plot_illumina_map({vertical => 1}); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, 100 different values, GA2 chip, where only an array of all tiles per lane is provided and wanted vertically');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{2dc5c2fee102c66bc57e8bab9d3fcfc2}, 'md5 hex digest of png is correct');
}

{
  my $non_integer_array_first = [qw(
    10 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6
    8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2
  )];
  my $non_integer_array = [qw(
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6
    8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2
  )];
  my $heatmap = npg::util::image::heatmap->new({
    data_array => [
      [@{$non_integer_array_first}],[@{$non_integer_array}],
      [@{$non_integer_array}],[@{$non_integer_array}],
      [@{$non_integer_array}],[@{$non_integer_array}],
      [@{$non_integer_array}],[@{$non_integer_array}]
    ],
  });

  my $png;
  eval { $png = $heatmap->plot_illumina_map({vertical => 1}); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, 330 different values, GA1 chip, where only an array of all tiles per lane is provided, and wanted vertically');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{67bec2aa2faa968464c3e478c912ccd1}, 'md5 hex digest of png is correct');
}

{
  my $heatmap = npg::util::image::heatmap->new({
    data_array => [
      [1..110],[111..220],[221..330],[1..110],[111..220],[221..330],
      [1..110],[111..220],[221..330],[1..110],[111..220],[221..330],
      [1..110],[111..220],[221..330],[1..110],[111..220],[221..330],
      [1..110],[111..220],[221..330],[1..110],[111..220],[221..330]
    ],
  });

  my $png;
  eval { $png = $heatmap->plot_illumina_map({
    tiles_per_lane => 330,
    vertical       => 1,
    colours        => [qw(red blue yellow)],
    tile_width     => 10,
  }); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, 330 different values, GA1 chip');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{a9ee5ae95003110dc44d70b1a4840fc4}, 'md5 hex digest of png is correct');
}

{
  my $non_integer_array = [qw(
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
  )];
  my $non_integer_array_first = [qw(
    10 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 85.3 4.00 7.4 100 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5 1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
    1.6 7.2 8.3 12.56 15.98 5.23 9.56 4.00 7.4 34.5
  )];
  my $heatmap = npg::util::image::heatmap->new({
    data_array => [
      [@{$non_integer_array_first}],[@{$non_integer_array}],
      [@{$non_integer_array}],[@{$non_integer_array}],
      [@{$non_integer_array}],[@{$non_integer_array}],
      [@{$non_integer_array}],[@{$non_integer_array}]
    ],
    tiles_per_lane => 100,
  });

  my $png;
  eval { $png = $heatmap->plot_illumina_map({vertical => 1, gradient_style => 'percentage'}); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, 100 different values, colours scaled by percentage');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{c53600da10e388295c018f80e6a8f9d9}, 'md5 hex digest of png is correct');
  my $image_map_reference = $heatmap->image_map_reference();
  isa_ok($image_map_reference, 'ARRAY', '$heatmap->image_map_reference()');
  is(scalar@{$image_map_reference}, 800, 'array has correct number of elements');
  isa_ok($image_map_reference->[0], 'ARRAY', '$image_map_reference->[0]');
  is(scalar@{$image_map_reference->[0]}, 5, 'array has correct number of elements');
  isa_ok($image_map_reference->[0]->[4], 'HASH', '$image_map_reference->[0]->[4]');
  is($image_map_reference->[0]->[4]->{position}, 1, '$image_map_reference->[0]->[4]->{position} is 1');
  is($image_map_reference->[0]->[4]->{tile}, 50, '$image_map_reference->[0]->[4]->{tile} is 1');
  is($image_map_reference->[0]->[4]->{value}, 34.5, '$image_map_reference->[0]->[4]->{value} is 1.6');
}

{
  my $heatmap = npg::util::image::heatmap->new({
    data_array => [
      [1..110],[111..220],[221..330],[10001..10110],[20111..20220],[30221..30330],
      [40001..40110],[40111..40220],[40221..40330],[10001..10110],[20111..20220],[30221..30330],
      [1..110],[111..220],[221..330],[10001..10110],[70111..70220],[30221..30330],
      [1..110],[111..220],[221..330],[10001..10110],[20111..20220],[30221..30330],
    ],
  });

  my $png;
  eval { $png = $heatmap->plot_illumina_map({tiles_per_lane => 330, gradient_style => 'cluster'}); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, 330 different values, colours scaled by cluster');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{58033e226e3f60679e0bb172a97f7aee}, 'md5 hex digest of png is correct');
}

{
  my $heatmap = npg::util::image::heatmap->new({
    data_array => [[1..60],[61..120],[121..180],[181..240],[241..300],[301..360],[361..420],[421..480],[1..60],[61..120],[121..180],[181..240],[241..300],[301..360],[361..420],[421..480]],
  });
  isa_ok($heatmap, 'npg::util::image::heatmap', '$heatmap');

  my $png;
  eval { $png = $heatmap->plot_illumina_map({tiles_per_lane => 120}); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, 480 different values, GA2 chip');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{645ea985aaaf4ac8ea59f9657c0b51b7}, 'md5 hex digest of png is correct');
}

{
  my $heatmap = npg::util::image::heatmap->new({
    data_array => [[1..55],[56..110],[111..165],[166..220],[221..275],[276..330],[331..385],[386..440],[1..55],[56..110],[111..165],[166..220],[221..275],[276..330],[331..385],[386..440]],
  });
  isa_ok($heatmap, 'npg::util::image::heatmap', '$heatmap');

  my $png;
  eval { $png = $heatmap->plot_illumina_map({tiles_per_lane => 110}); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, 440 different values, GA2 chip');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{4b01f2ecbfc4c252661caee50d4fd288}, 'md5 hex digest of png is correct');
}
1;
__END__
