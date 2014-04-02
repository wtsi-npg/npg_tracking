use strict;
use warnings;
use English qw{-no_match_vars};
use Test::More tests => 16;
use Digest::MD5;

my $md5_object = Digest::MD5->new();

use_ok('npg::util::image::scale');

{
  my $scale = npg::util::image::scale->new({});
  isa_ok($scale, 'npg::util::image::scale', '$scale');

  my $png;
  eval { $png = $scale->plot_scale({ orientation => 'horizontal' }); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, horizontal');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{f5361baf23e82e467dd14993776cfee5}, 'md5 hex digest of png is correct');

  eval { $png = $scale->plot_scale(); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, vertical');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{6e391736c8d19c352f25a774adc296f1}, 'md5 hex digest of png is correct');

  eval { $png = $scale->plot_scale({
    image_height => 260,
    image_width  => 100,
    bar_height   => 255,
    bar_width    => 6,
    colours      => [qw(green red purple blue)],
    start_text   => 0,
    end_text     => 200_000,
  }); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, vertical');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{27deeb8f0265311a355e5249fa2331d6}, 'md5 hex digest of png is correct');

  eval { $png = $scale->plot_scale({
    image_height => 260,
    image_width  => 100,
    bar_height   => 255,
    bar_width    => 6,
    start_text   => 0,
    end_text     => 200_000,
    gradient_steps => 200,
  }); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, vertical');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{36922d6a94150c62b0e9c1610128dec5}, 'md5 hex digest of png is correct');

  eval { $png = $scale->plot_scale({
    end_text    => 200_000,
    orientation => 'horizontal',
  }); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, vertical');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{c97655e48385fc181bfe094d40e0d430}, 'md5 hex digest of png is correct');

  eval { $png = $scale->plot_scale({
    image_height => 10,
    image_width  => 10,
    bar_height   => 10,
    bar_width    => 10,
  }); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png image, vertical');
  $md5_object->add($png);
  is($md5_object->hexdigest(), q{91cac23bc1c18535d7b41a1b0c54effb}, 'md5 hex digest of png is correct');
  
    eval { $png = $scale->get_legend({
    image_height => 260,
    image_width  => 100,
    bar_height   => 255,
    bar_width    => 6,
    colours      => [qw(grey black yellow red)],
    side_texts   => [qw(n/a <5k 5k-10k >10k)],
  }); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png legend image, vertical');
  
  eval { $png = $scale->get_legend({
    image_height => 50,
    image_width  => 260,
    bar_height   => 6,
    bar_width    => 255,
    orientation  => q(horizontal),
    colours      => [qw(grey black yellow red)],
    side_texts   => [qw(n/a <5k 5k-10k >10k)],
  }); } or do { warn $EVAL_ERROR; };
  is($EVAL_ERROR, q{}, 'no croak on generation of png legend image, horizontal');
 
}
