#########
# Author:        ajb
# Created:       2008-08-07
#
package npg::util::image::merge;
use strict;
use warnings;
use English qw{-no_match_vars};
use GD;
use GD::Image;
use base qw(npg::util::image::image);
use npg::util::image::graph;
use Carp qw(carp croak cluck confess);
use POSIX qw(floor ceil);
use Readonly;

our $VERSION = '0';

Readonly::Scalar our $GRAPH_HEIGHT_DEFAULT          => 200;
Readonly::Scalar our $GRAPH_WIDTH_DEFAULT           => 400;
Readonly::Scalar our $HEIGHT_OF_COLUMN_HEADINGS_TP  => 50;
Readonly::Scalar our $WIDTH_OF_ROW_HEADINGS_TP      => 60;
Readonly::Scalar our $RIGHT_MARGIN_TP               => 25;
Readonly::Scalar our $BOTTOM_MARGIN_TP              => 40;
Readonly::Scalar our $HEIGHT_OF_COLUMN_HEADINGS_TL  => 40;
Readonly::Scalar our $WIDTH_OF_ROW_HEADINGS_TL      => 80;
Readonly::Scalar our $RIGHT_MARGIN_TL               => 65;
Readonly::Scalar our $BOTTOM_MARGIN_TL              => 25;
Readonly::Scalar our $THIRD                         => 3;
Readonly::Scalar our $QUARTER                       => 4;
Readonly::Scalar our $EXTRA_FIVE_PIXELS             => 5;
Readonly::Scalar our $EXTRA_EIGHT_PIXELS            => 8;
Readonly::Scalar our $EXTRA_TEN_PIXELS              => 10;
Readonly::Scalar our $TILE_REF_ALL_ERROR_THUMBS     => 0;
Readonly::Scalar our $IMAGE_ALL_ERROR_THUMBS        => 1;
Readonly::Scalar our $Y_TEXT_POS_ALL_ERROR_THUMBS   => 2;
Readonly::Scalar our $Y_BORDER_POS_ALL_ERROR_THUMBS => 3;
Readonly::Scalar our $SPACE_TILE_REF_ALL_ERROR_THUMBS => 107;
Readonly::Scalar our $S_LESS_ONE_BORDER_TILE_REF_ALL_ERROR_THUMBS => 105;
Readonly::Scalar our $S_LESS_BOTH_BORDERS_TILE_REF_ALL_ERROR_THUMBS => 103;
Readonly::Scalar our $X_POS_IMAGE_TITLE_ALL_ERROR_THUMBS => 130;
Readonly::Scalar our $WHITE => 255;
Readonly::Scalar our $DEFAULT_TEXT_BOX_WIDTH => 150;
Readonly::Scalar our $DEFAULT_TEXT_BOX_HEIGHT => 25;
Readonly::Scalar our $TEXT_BOX_TEXT_POSITION_X_Y => 5;
Readonly::Scalar our $TEXT_BOX_POSITION => 3;


sub allowed_formats {
  my ($self, $format) = @_;
  my $allowed_formats = {
    table_portrait             => 1,
    table_landscape            => 1,
    all_error_thumbs           => 1,
    add_two_graphs_portrait    => 1,
    overlay_all_images_exactly => 1,
    gantt_chart_vertical       => 1,
    add_text_box               => 1,
  };
  if (!$allowed_formats->{$format}) {
    croak "$format is not a supported format of merged images";
  }
  return 1;
}

sub merge_images {
  my ($self, $arg_refs) = @_;
  my $format = $arg_refs->{format};
  $self->allowed_formats($format);
  return $self->$format($arg_refs);
}

sub add_text_box {
  my ($self, $arg_refs) = @_;

  my $base_image = GD::Image->new($arg_refs->{image}) || croak q{unable to create new image object from png};

  my $text_box = $self->_text_box($arg_refs);

  $base_image->copy($text_box, $arg_refs->{text_box_width}/$TEXT_BOX_POSITION, $arg_refs->{text_box_height}, 0, 0, $arg_refs->{text_box_width}, $arg_refs->{text_box_height});

  return $base_image->png();
}

sub _text_box {
  my ($self, $arg_refs) = @_;
  $arg_refs->{text_box_width}  ||= $DEFAULT_TEXT_BOX_WIDTH;
  $arg_refs->{text_box_height} ||= $DEFAULT_TEXT_BOX_HEIGHT;

  my $text       = $arg_refs->{text};
  my $box_width  = $arg_refs->{text_box_width};
  my $box_height = $arg_refs->{text_box_height};


  my $im = GD::Image->new($box_width,$box_height);
  my $white = $im->colorAllocate($WHITE,$WHITE,$WHITE);
  my $black = $im->colorAllocate(0,0,0);

  $im->rectangle(0,0,$box_width-1,$box_height-1,$black);

  $im->string(gdGiantFont, $TEXT_BOX_TEXT_POSITION_X_Y, $TEXT_BOX_TEXT_POSITION_X_Y, $text, $black);
  return $im;
}

sub table_portrait {
  my ($self, $arg_refs) = @_;

  my $data           = $arg_refs->{data};

  if (!$data || !$data->[0]) {
    croak 'no data provided for drawing images';
  }

  my $col_headings   = $arg_refs->{col_headings};
  my $row_headings   = $arg_refs->{row_headings};
  my $args_for_image = $arg_refs->{args_for_image};
  my $titles         = $arg_refs->{titles};
  my $y_min_values   = $arg_refs->{y_min_values};
  my $y_max_values   = $arg_refs->{y_max_values};
  my $y_labels       = $arg_refs->{y_labels};

  my $rows = scalar@{$data} || 0;
  my $cols = scalar@{$data->[0]} || 0;

  $args_for_image->{return_object} = 1;

  my $row_count = 0;
  foreach my $row (@{$data}) {
    my $col_count = 0;
    foreach my $col (@{$row}) {
      my $args = \%{$args_for_image};

      if ($titles) {
        $args->{title} = $titles->[$col_count];
      }
      if ($y_min_values) {
        $args->{y_min_value} = $y_min_values->[$col_count];
      }
      if ($y_max_values) {
        $args->{y_max_value} = $y_max_values->[$col_count];
      }
      if ($y_labels) {
        $args->{y_label} = $y_labels->[$col_count];
      }

      eval {
        my $image = npg::util::image::graph->new();
        $col = $image->plotter($col, $args, q{lines}, 1);
      } or do {
        croak $EVAL_ERROR;
      };

      $col_count++;
    }
    $row_count++;
  }

  my $height_of_image = $args_for_image->{height} || $GRAPH_HEIGHT_DEFAULT;
  my $width_of_image  = $args_for_image->{width}  || $GRAPH_WIDTH_DEFAULT;

  my $height = $rows * $height_of_image + $HEIGHT_OF_COLUMN_HEADINGS_TP + $BOTTOM_MARGIN_TP;
  my $width  = $cols * $width_of_image  + $WIDTH_OF_ROW_HEADINGS_TP + $RIGHT_MARGIN_TP;

  my $im = GD::Image->new($width,$height);

  $row_count = 0;
  foreach my $row (@{$data}) {
    my $col_count = 0;
    foreach my $col (@{$row}) {
      my $x_pos = $WIDTH_OF_ROW_HEADINGS_TP + 2 + $col_count*($col->width() + $EXTRA_EIGHT_PIXELS);
      my $y_pos = $HEIGHT_OF_COLUMN_HEADINGS_TP + $row_count*($col->height() + $EXTRA_FIVE_PIXELS);

# uncomment if you want positions for an image map to be outputed
#      my $x_final = $x_pos + $col->width();
#      my $y_final = $y_pos + $col->height();
#      print qq{<area coords="($x_pos $y_pos $x_final $y_final)[0..3]" href="" title="">\n};

      $im->copy($col, $x_pos, $y_pos, 0,0,$width_of_image,$height_of_image);
      $col_count++;
      $arg_refs->{height_of_image} = $col->height();
      $arg_refs->{width_of_image}  = $col->width();
    }
    $row_count++;
  }
  $self->draw_table_text_tp($arg_refs, $im);
  $self->draw_table_borders_tp($arg_refs, $im);

#open (FH, ">:raw", 'image.png') || croak 'could not open';print FH $im->png;close FH;
  return $im->png();

}

sub draw_table_text_tp {
  my ($self, $arg_refs, $im) = @_;

  my $width  = $im->width();
  my $height = $im->height();

  my $text_colour = $im->colorAllocate(0,0,0);

  my $column_headings = $arg_refs->{column_headings};
  my $row_headings = $arg_refs->{row_headings};

  my $height_of_image = $arg_refs->{height_of_image};
  my $width_of_image  = $arg_refs->{width_of_image};

  my $count = 0;
  foreach my $text (@{$column_headings}) {
    my $x = $WIDTH_OF_ROW_HEADINGS_TP/$QUARTER + ($width_of_image*$count);
    if ($count > 0) { $x -= $width_of_image/2; };
    my $y = $HEIGHT_OF_COLUMN_HEADINGS_TP/2;
    $im->string(gdGiantFont, $x, $y, $text, $text_colour);
    $count++;
  }
  $count = 1;
  foreach my $text (@{$row_headings}) {
    my $x = $WIDTH_OF_ROW_HEADINGS_TP/2;
    my $y = $HEIGHT_OF_COLUMN_HEADINGS_TP + $height_of_image*$count - $height_of_image/2;
    $im->string(gdGiantFont, $x, $y, $text, $text_colour);
    $count++;
  }

  return 1;
}

sub draw_table_borders_tp {
  my ($self, $arg_refs, $im) = @_;

  my $width  = $im->width();
  my $height = $im->height();

  my $border_colour = $im->colorAllocate(0,0,0);

  my $height_of_image = $arg_refs->{height_of_image};
  my $width_of_image  = $arg_refs->{width_of_image};
  my $column_headings = $arg_refs->{column_headings};
  my $row_headings = $arg_refs->{row_headings};

  $im->rectangle(0,0,$width-1,$height-1,$border_colour);

  my $count = 0;
  foreach my $heading (@{$column_headings}) {
    $im->rectangle(($WIDTH_OF_ROW_HEADINGS_TP + $count * ($width_of_image + $EXTRA_EIGHT_PIXELS) - 1), 0, ($WIDTH_OF_ROW_HEADINGS_TP + $count * ($width_of_image + $EXTRA_EIGHT_PIXELS)), $height, $border_colour);
    $count++;
  }
  $count = 0;
  foreach my $heading (@{$row_headings}) {
    $im->rectangle(0,($HEIGHT_OF_COLUMN_HEADINGS_TP + $count * ($height_of_image + $EXTRA_FIVE_PIXELS) - 2), $width, ($HEIGHT_OF_COLUMN_HEADINGS_TP + $count * ($height_of_image + $EXTRA_FIVE_PIXELS) - 1), $border_colour);
    $count++;
  }
  return 1;
}
sub draw_table_borders_tl {
  my ($self, $arg_refs, $im) = @_;

  my $width  = $im->width();
  my $height = $im->height();

  my $border_colour = $im->colorAllocate(0,0,0);

  my $height_of_image = $arg_refs->{height_of_image};
  my $width_of_image  = $arg_refs->{width_of_image};
  my $column_headings = $arg_refs->{column_headings};
  my $row_headings    = $arg_refs->{row_headings};

  $im->rectangle(0,0,$width-1,$height-1,$border_colour);

  my $count = 0;
  foreach my $heading (@{$column_headings}) {
    $im->rectangle(($WIDTH_OF_ROW_HEADINGS_TL + $count * ($width_of_image + $EXTRA_EIGHT_PIXELS) - 1), 0, ($WIDTH_OF_ROW_HEADINGS_TL + $count * ($width_of_image + $EXTRA_EIGHT_PIXELS)), $height, $border_colour);
    $count++;
  }
  $count = 0;
  foreach my $heading (@{$row_headings}) {
    $im->rectangle(0,($HEIGHT_OF_COLUMN_HEADINGS_TL + $count * ($height_of_image + $EXTRA_FIVE_PIXELS) - 2), $width, ($HEIGHT_OF_COLUMN_HEADINGS_TL + $count * ($height_of_image + $EXTRA_FIVE_PIXELS) - 1), $border_colour);
    $count++;
  }
  return 1;
}

sub draw_table_text_tl {
  my ($self, $arg_refs, $im) = @_;

  my $width  = $im->width();
  my $height = $im->height();

  my $text_colour = $im->colorAllocate(0,0,0);

  my $column_headings = $arg_refs->{column_headings};
  my $row_headings    = $arg_refs->{row_headings};

  my $height_of_image = $arg_refs->{height_of_image};
  my $width_of_image  = $arg_refs->{width_of_image};

  my $count = 1;
  my @column_headings = @{$column_headings};
  my $row_heading_space_heading = shift @column_headings;
  my $x = $WIDTH_OF_ROW_HEADINGS_TL/$QUARTER;
  my $y = $HEIGHT_OF_COLUMN_HEADINGS_TL/2;
  $im->string(gdGiantFont, $x, $y, $row_heading_space_heading, $text_colour);
  foreach my $text (@column_headings) {
    my $x_new = $WIDTH_OF_ROW_HEADINGS_TL + ($width_of_image*$count) - ($width_of_image/2) + (($count - 1) * $EXTRA_EIGHT_PIXELS);
    $im->string(gdGiantFont, $x_new, $y, $text, $text_colour);
    $count++;
  }
  $count = 1;
  foreach my $text (@{$row_headings}) {
    my @temp = split /\s+/xms, $text;
    my $y_new = $HEIGHT_OF_COLUMN_HEADINGS_TL + $height_of_image*$count - $height_of_image/2;
    if (scalar@temp == 1) {
      $im->string(gdGiantFont, $x, $y_new, $text, $text_colour);
    } else {
      my $text_1 = $temp[0]. q{ }. $temp[1];
      $im->string(gdGiantFont, $x, $y_new, $text_1, $text_colour);
      my $text_2 = $temp[2];
      $y_new = $y_new + $height_of_image/$THIRD;
      $im->string(gdGiantFont, $x, $y_new, $text_2, $text_colour);
    }
    $count++;
  }

  return 1;
}

sub table_landscape {
  my ($self, $arg_refs) = @_;

  my $data           = $arg_refs->{data};

  if (!$data || !$data->[0]) {
    croak 'no data provided for drawing images';
  }

  my $col_headings   = $arg_refs->{col_headings};
  my $row_headings   = $arg_refs->{row_headings};
  my $args_for_image = $arg_refs->{args_for_image};
  my $titles         = $arg_refs->{titles};
  my $y_min_values   = $arg_refs->{y_min_values};
  my $y_max_values   = $arg_refs->{y_max_values};
  my $y_labels       = $arg_refs->{y_labels};

  my $rows = scalar@{$data} || 0;
  my $cols = scalar@{$data->[0]} || 0;

  $args_for_image->{return_object} = 1;

  my $row_count = 0;
  foreach my $row (@{$data}) {
    my $col_count = 0;
    foreach my $col (@{$row}) {
      my $args = \%{$args_for_image};

      if ($titles) {
        $args->{title} = $titles->[$row_count];
      }
      if ($y_min_values) {
        $args->{y_min_value} = $y_min_values->[$row_count];
      }
      if ($y_max_values) {
        $args->{y_max_value} = $y_max_values->[$row_count];
      }
      if ($y_labels) {
        $args->{y_label} = $y_labels->[$row_count];
      }

      eval {
        my $image = npg::util::image::graph->new();
        $col = $image->plotter($col, $args, q{lines}, 1);
      } or do {
        croak $EVAL_ERROR;
      };

      $col_count++;
    }
    $row_count++;
  }

  my $height_of_image = $args_for_image->{height} || $GRAPH_HEIGHT_DEFAULT;
  my $width_of_image  = $args_for_image->{width}  || $GRAPH_WIDTH_DEFAULT;

  my $height = $rows * $height_of_image + $HEIGHT_OF_COLUMN_HEADINGS_TL + $BOTTOM_MARGIN_TL;
  my $width  = $cols * $width_of_image  + $WIDTH_OF_ROW_HEADINGS_TL + $RIGHT_MARGIN_TL;

  my $im = GD::Image->new($width,$height);

  $row_count = 0;
  foreach my $row (@{$data}) {
    my $col_count = 0;
    foreach my $col (@{$row}) {
      my $x_pos = $WIDTH_OF_ROW_HEADINGS_TL + 2 + $col_count*($col->width() + $EXTRA_EIGHT_PIXELS);
      my $y_pos = $HEIGHT_OF_COLUMN_HEADINGS_TL + $row_count*($col->height() + $EXTRA_FIVE_PIXELS);

# uncomment if you want positions for an image map to be outputed
#      my $x_final = $x_pos + $col->width();
#      my $y_final = $y_pos + $col->height();
#      print qq{<area coords="($x_pos $y_pos $x_final $y_final)[0..3]" href="" title="">\n};

      $im->copy($col, $x_pos, $y_pos, 0,0,$width_of_image,$height_of_image);
      $col_count++;
      $arg_refs->{height_of_image} = $col->height();
      $arg_refs->{width_of_image}  = $col->width();
    }
    $row_count++;
  }
  $self->draw_table_text_tl($arg_refs, $im);
  $self->draw_table_borders_tl($arg_refs, $im);

#open (FH, ">:raw", 'image.png') || croak 'could not open';print FH $im->png;close FH;
  return $im->png();

}

sub add_two_graphs_portrait {
  my ($self, $arg_refs) = @_;

  my $width = $arg_refs->{width};
  my $height = $arg_refs->{height}*2;

  my $im = GD::Image->new($width,$height);
  $im->copy($arg_refs->{graph_1}, 0, 0, 0, 0,$arg_refs->{width}, $arg_refs->{height});
  $im->copy($arg_refs->{graph_2}, 0, $arg_refs->{height}, 0, 0,$arg_refs->{width}, $arg_refs->{height});

  return $im->png();
}

sub all_error_thumbs {
  my ($self, $arg_refs) = @_;

  my $data           = $arg_refs->{data};

  if (!$data) {
    croak 'no data provided for drawing images';
  }

  my $col_headings   = $arg_refs->{col_headings};
  my $args_for_image = $arg_refs->{args_for_image};

  my $rows;

  $args_for_image->{return_object} = 1;
  $args_for_image->{legend} = undef;

  my $max_lane = scalar@{$data};
  foreach my $lane (1..$max_lane) {
    next if (!$data->[$lane]);
    my $tiles = $data->[$lane];
    my $max_tile = scalar@{$tiles} - 1;
    foreach my $tile (1..$max_tile) {
      my $tile_info = $tiles->[$tile];

      eval {
        my $e_image = npg::util::image::graph->new();
        my $ep = $e_image->plotter($tile_info->{error_percentage}, $args_for_image, q{area}, 1);
        my $b_image = npg::util::image::graph->new();
        my $bp = $b_image->plotter($tile_info->{blank_percentage}, $args_for_image, q{area}, 1);

        if (ref$ep eq 'GD::Image' && ref$bp eq 'GD::Image') {
          $tile_info->{joined_graphs} = GD::Image->new($args_for_image->{width},$args_for_image->{height}*2);
          $tile_info->{joined_graphs}->copy($ep, 0, 0, 0, 0,$args_for_image->{width}, $args_for_image->{height});
          $tile_info->{joined_graphs}->copy($bp, 0, $args_for_image->{height}, 0, 0,$args_for_image->{width}, $args_for_image->{height});
        }
        1;
      } or do {

        confess $EVAL_ERROR;
      };

      my $tile_ref = $arg_refs->{id_run} . q{_} . $lane . q{_} . sprintf '%03d', $tile;
      push @{$rows}, [$tile_ref, $tile_info->{joined_graphs}];
    }

  }
  my $cmh = scalar@{$rows} * 2 * ($args_for_image->{height}+$EXTRA_FIVE_PIXELS) + $HEIGHT_OF_COLUMN_HEADINGS_TL;
  my $cmw = $args_for_image->{width} + $SPACE_TILE_REF_ALL_ERROR_THUMBS;
  my $cm  = GD::Image->new($cmw, $cmh);

  my $count = 0;
  my $im_map_ref = [];
  foreach my $row (@{$rows}) {

    my $y = ($HEIGHT_OF_COLUMN_HEADINGS_TL + $count * 2 * ($args_for_image->{height}+$EXTRA_FIVE_PIXELS));
    $row->[$Y_TEXT_POS_ALL_ERROR_THUMBS] = $y + $args_for_image->{height} - $EXTRA_TEN_PIXELS;
    $row->[$Y_BORDER_POS_ALL_ERROR_THUMBS] = $y - 2;

    if (ref$row->[$IMAGE_ALL_ERROR_THUMBS] eq 'GD::Image') {

      my $x2 = $S_LESS_ONE_BORDER_TILE_REF_ALL_ERROR_THUMBS + $args_for_image->{width};
      my $y2 = $y + (2 * $args_for_image->{height});

      push @{$im_map_ref}, {
        'tile_ref' => $row->[$TILE_REF_ALL_ERROR_THUMBS],
        'x1' => $S_LESS_ONE_BORDER_TILE_REF_ALL_ERROR_THUMBS,
        'y1' => $y,
        'x2' => $x2,
        'y2' => $y2,
      };

      $cm->copy($row->[$IMAGE_ALL_ERROR_THUMBS], $S_LESS_ONE_BORDER_TILE_REF_ALL_ERROR_THUMBS, $y, 0, 0, $args_for_image->{width}, 2 * $args_for_image->{height});

    }
    $count++;
  }
  $self->image_map_reference($im_map_ref);
  $self->error_add_text($cm, $rows, $args_for_image);
  $self->error_table_borders($cm, $rows, $args_for_image);
#open (FH, ">:raw", 'image.png') || croak 'could not open';print FH $im->png;close FH;

  return $cm->png();

}

sub error_add_text {
  my ($self, $im, $rows, $args_for_image) = @_;

  my $width  = $im->width();
  my $height = $im->height();

  my $text_colour = $im->colorAllocate(0,0,0);

  $im->string(gdGiantFont, $EXTRA_FIVE_PIXELS, $EXTRA_FIVE_PIXELS, 'Tile Ref', $text_colour);
  $im->string(gdGiantFont, $X_POS_IMAGE_TITLE_ALL_ERROR_THUMBS, $EXTRA_FIVE_PIXELS, 'Image', $text_colour);

  foreach my $r (@{$rows}) {
    $im->string(gdGiantFont, $EXTRA_FIVE_PIXELS, $r->[$Y_TEXT_POS_ALL_ERROR_THUMBS], $r->[$TILE_REF_ALL_ERROR_THUMBS], $text_colour);
  }

  return 1;
}

sub error_table_borders {
  my ($self, $im, $rows, $args_for_image) = @_;

  my $width  = $im->width();
  my $height = $im->height();

  my $border_colour = $im->colorAllocate(0,0,0);

  $im->rectangle(0,0,$width-1,$height-1,$border_colour);
  $im->rectangle($S_LESS_BOTH_BORDERS_TILE_REF_ALL_ERROR_THUMBS,0,$S_LESS_BOTH_BORDERS_TILE_REF_ALL_ERROR_THUMBS,$height-1,$border_colour);
  foreach my $r (@{$rows}) {
    $im->rectangle(0,$r->[$Y_BORDER_POS_ALL_ERROR_THUMBS],$width-1,$r->[$Y_BORDER_POS_ALL_ERROR_THUMBS],$border_colour);
  }

  return 1;
}

sub overlay_all_images_exactly {
  my ($self, $arg_refs) = @_;
  if (!$arg_refs->{images}->[0]) {
    croak q{No images};
  }
  my $first_image = GD::Image->new($arg_refs->{images}->[0]) || croak q{unable to create new image object from png};
  my $width  = $first_image->width();
  my $height = $first_image->height();
  my $im = GD::Image->new($width,$height);
  my $white = $im->colorAllocate($WHITE,$WHITE,$WHITE);
  if ($arg_refs->{white_is_transparent}) {
    $im->transparent($white);
  }
  if ($arg_refs->{all_white_is_transparent}) {
    my $first_image_white = $first_image->colorClosest($WHITE,$WHITE,$WHITE);
    $first_image->transparent($first_image_white);
  }
  foreach my $image (@{$arg_refs->{images}}) {

    my $temp_image = GD::Image->new($image) || croak q{unable to create new image object from png};
    if ($arg_refs->{all_white_is_transparent}) {
      my $temp_white = $temp_image->colorClosest($WHITE,$WHITE,$WHITE);
      $temp_image->transparent($temp_white);
    }

    $im->copy($temp_image, 0, 0, 0, 0,$width, $height);
  }
#open (FH, ">:raw", 'image.png') || croak 'could not open';print FH $im->png();close FH;
  return $im->png();
}
sub gantt_chart_vertical {
  my ($self, $arg_refs) = @_;
  my $images = [];
  my $graph = npg::util::image::graph->new({});
  my $args_for_each = {
    x_label         => $arg_refs->{x_label},
    y_label         => $arg_refs->{y_label},
    y_max_value     => $arg_refs->{y_max_value},
    y_min_value     => $arg_refs->{y_min_value},
    height          => $arg_refs->{height},
    width           => $arg_refs->{width},
    borderclrs      => $arg_refs->{borderclrs},
    y_tick_number   => $arg_refs->{y_tick_number},
    y_number_format => $arg_refs->{y_number_format},
  };
  my $x_axis = $arg_refs->{x_axis};
  my $colour = $arg_refs->{colour_of_block} || q{red};
  my $colours = [$colour, q{white}];
  ## first row of point levels should always be where the block needs to be turned off,
  ## then alternating on/off working from top of graph down
  ## if all blocks done/no blocks at all, just continue to put 0 in the space
  foreach my $point_levels (@{$arg_refs->{data_points}}) {
    $graph->colours($colours);
    my $data = [$x_axis,$point_levels];
    my $png;
    eval { $png = $graph->plotter($data, $args_for_each, q{bars}, 1); } or do { croak q{Problem generating graph: } .$EVAL_ERROR; };
    push @{$images}, $png;
    $colours = $self->_switch_two_colour_array($colours);
  }

  $self->gantt_refs($graph->data_point_refs);

  if ($arg_refs->{add_points}) {
    $arg_refs->{args_for_each} = $args_for_each;
    push @{$images}, $self->_add_points($arg_refs);
  }
  return $self->overlay_all_images_exactly({images => $images});
}

sub _switch_two_colour_array {
  my ($self, $colours) = @_;
  return [$colours->[1], $colours->[0]];
}

sub _add_points {
  my ($self, $arg_refs) = @_;

  my $colours = [];
  if ($arg_refs->{colour_of_block} && $arg_refs->{colour_of_block} eq q{black}) {
    push @{$colours}, q{red};
  } else {
    push @{$colours}, q{black};
  }
  my $x_axis = $arg_refs->{x_axis};
  my $args_for_each = $arg_refs->{args_for_each};
  $args_for_each->{correct_width} = 1;
  my $graph = npg::util::image::graph->new({colours => $colours});
  my $images = [];
  ## point data can be in any order , but undefs are needed where no further/any data points are needed for a column
  foreach my $point_levels (@{$arg_refs->{add_points}}) {
    my $data = [$x_axis,$point_levels];
    my $png;
    eval { $png = $graph->plotter($data, $args_for_each, q{points}, 1); } or do { croak q{Problem generating graph: } .$EVAL_ERROR; };
    push @{$images}, $png;
  }
  $self->data_point_refs($graph->data_point_refs);
  return $self->overlay_all_images_exactly({images => $images, white_is_transparent => 1});
}

1;

__END__

=head1 NAME

npg::util::image::merge

=head1 VERSION

=head1 SYNOPSIS

  my $oImageMerge = npg::util::image::merge->new({});

=head1 DESCRIPTION

Wrapper object to provide a scale image showing the colours in a linear gradient and the min and max values;

=head1 SUBROUTINES/METHODS

=head2 new - constructor to create a graph object

=head2 build_linear_gradient - routine to obtain a scale of colours from given colours. Defaults from black through yellow to red

=head2 merge_images - default method to call

=head2 allowed_formats - checks supplied format to merge into is an allowed format

=head2 draw_table_borders_tp - draws borders on the image so a table style view appears
=head2 draw_table_text_tp - Puts headers into the image to look like a table
=head2 table_portrait - method table creates a table-style merged image
=head2 draw_table_borders_tl - draws borders on the image so a table style view appears
=head2 draw_table_text_tl - Puts headers into the image to look like a table
=head2 table_landscape - method table creates a table-style merged image
=head2 add_two_graphs_portrait - joins two GD::Image graph objects into one image portrait - nothing fancy
=head2 all_error_thumbs - takes an array of data for error_rates and creates a joined image of all the thumbnails
=head2 error_add_text - used by all_error_thumbs
=head2 error_table_borders - used by all error_thumbs
=head2 overlay_all_images_exactly - takes an array of image objects and overlays them all exactly. Assumes that the first image has the correct height and width to use.
=head2 gantt_chart_vertical takes a data set for bar charts and produces a gantt style image
=head2 add_text_box - takes an image, and adds a simple text box near the top left corner

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

GD
GD::Image
Class::Accessor
npg::util::image::image
npg::util::image::graph

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown, E<lt>ajb@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 GRL, by Andy Brown

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
