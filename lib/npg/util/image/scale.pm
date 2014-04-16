#########
# Author:        ajb
# Created:       2008-08-07
#
package npg::util::image::scale;
use strict;
use warnings;
use GD;
use GD::Image;
use base qw(npg::util::image::image);
use Carp;
use POSIX qw(floor ceil);
use Readonly;

our $VERSION = '0';

Readonly::Scalar our $VERTICAL_DEFAULTS => {
                                    BAR_WIDTH    => 6,
                                    BAR_HEIGHT   => 255,
                                    IMAGE_WIDTH  => 100,
                                    IMAGE_HEIGHT => 260,
                                   };

Readonly::Scalar our $HORIZONTAL_DEFAULTS => {
                                      BAR_WIDTH    => 255,
                                      BAR_HEIGHT   => 6,
                                      IMAGE_WIDTH  => 275,
                                      IMAGE_HEIGHT => 40,
                                     };

Readonly::Scalar our $DEFAULT_TEXT => {
                                START => 0,
                                END   => 'End',
                              };

Readonly::Scalar our $GDSMALL_FONT_PIXELS                            => 15;
Readonly::Scalar our $MULTIPLIER_FOR_HORIZONTAL_POSITION_OF_END_TEXT => 3;
Readonly::Scalar our $HALF_DIVISION                                  => 2;
Readonly::Scalar our $QUARTER_DIVISION                               => 4;
Readonly::Scalar our $THIRD_DIVISION                                 => 3;
Readonly::Scalar our $ALLOCATE_WHITE                                 => 255;

sub plot_scale {
  my ($self, $arg_refs) = @_;

  $arg_refs->{orientation}    ||= q{vertical};
  $arg_refs->{start_text}     ||= $DEFAULT_TEXT->{START};
  $arg_refs->{end_text}       ||= $DEFAULT_TEXT->{END};
  $arg_refs->{gradient_steps} ||= q{};


  my $defaults = $arg_refs->{orientation} eq 'vertical' ? $VERTICAL_DEFAULTS
               :                                          $HORIZONTAL_DEFAULTS
               ;

  my $image_height  = $arg_refs->{image_height} || $defaults->{IMAGE_HEIGHT};
  my $image_width   = $arg_refs->{image_width}  || $defaults->{IMAGE_WIDTH};

  my $bar_height    = $arg_refs->{bar_height}   || $defaults->{BAR_HEIGHT};
  my $bar_width     = $arg_refs->{bar_width}    || $defaults->{BAR_WIDTH};

  my $max_pixels = $arg_refs->{orientation} eq 'vertical' ? $bar_height
                 :                                          $bar_width
                 ;

  my $linear_gradient = $self->build_linear_gradient($arg_refs->{colours}, q{}, $arg_refs->{gradient_steps}, q{scale});

  my $im = GD::Image->new($image_width,$image_height);

  my $white = $im->colorAllocate($ALLOCATE_WHITE,$ALLOCATE_WHITE,$ALLOCATE_WHITE);
  $im->transparent($white);

  my $text_colour = $im->colorAllocate(0,0,0);

  foreach my $colour (@{$linear_gradient}) {
    $colour = $im->colorAllocate(@{$colour});
  }

  my $all_data_points = $self->give_pixels_a_gradient($im, $max_pixels, $linear_gradient);

  my $gap_width  = $arg_refs->{orientation} eq 'vertical' ? sprintf '%.00f', (($image_width  - $bar_width ) / $QUARTER_DIVISION)
                 :                                          sprintf '%.00f', (($image_width  - $bar_width ) / $HALF_DIVISION)
                 ;

  my $gap_height = $arg_refs->{orientation} eq 'vertical' ? sprintf '%.00f', (($image_height - $bar_height) / $HALF_DIVISION)
                 :                                          sprintf '%.00f', (($image_height - $bar_height) / $QUARTER_DIVISION)
                 ;


  if ($arg_refs->{orientation} eq 'vertical') {

    $im->string(gdSmallFont,(2 * $gap_width), $gap_height,$arg_refs->{start_text}, $text_colour);
    $im->string(gdSmallFont,(2 * $gap_width), ($image_height - $gap_height - $GDSMALL_FONT_PIXELS), $arg_refs->{end_text},$text_colour);

  } else {

    $im->string(gdSmallFont,$gap_width,$gap_height,$arg_refs->{start_text},$text_colour);

    my $multiplier = length $arg_refs->{end_text} > $MULTIPLIER_FOR_HORIZONTAL_POSITION_OF_END_TEXT ? (length $arg_refs->{end_text}) - 1
                   :                                                                                  $MULTIPLIER_FOR_HORIZONTAL_POSITION_OF_END_TEXT
                   ;

    $im->string(gdSmallFont,($image_width  - $multiplier * $gap_width),$gap_height,$arg_refs->{end_text},$text_colour);

  }

  foreach my $i (1..$max_pixels) {

    my ($x1, $x2, $y1, $y2);

    if ($arg_refs->{orientation} eq 'vertical') {
      $x1 = $gap_width;
      $x2 = $x1 + $bar_width;
      $y1 = $gap_height + $i - 1;
      $y2 = $y1 + 1;
    } else {
      $x1 = $gap_width + $i;
      $x2 = $x1 + 1;
      $y1 = $THIRD_DIVISION * $gap_height;
      $y2 = $y1 + $bar_height;
    }

    my $colour = $all_data_points->[$i];

    $im->filledRectangle($x1,$y1,$x2,$y2,$colour);

  }

#open (FH, ">:raw", 'image.png') || croak 'could not open';print FH $im->png;close FH;
  return $im->png;
}

sub give_pixels_a_gradient {
  my ($self, $im, $max_pixels, $linear_gradient) = @_;

  my $all_data_points = [[]];

  my $group_count = $max_pixels/scalar@{$linear_gradient};

  if ($group_count >= 1) {

    $group_count = ceil($group_count);

    my $count = 1;
    my $gradient_index = 0;

    foreach my $i (1..$max_pixels) {

      push @{$all_data_points}, $linear_gradient->[$gradient_index];

      if ($count == $group_count) {
        $count = 1;
        $gradient_index++;
      } else {
        $count++
      }

    }

  } else {

    $group_count = scalar@{$linear_gradient}/$max_pixels;
    $group_count = floor($group_count);

    my $gradient_index = 0;

    foreach my $i (1..$max_pixels) {

      push @{$all_data_points}, $linear_gradient->[$gradient_index];

      $gradient_index += $group_count;

    }

  }

  return $all_data_points;
}

sub get_legend {
  my ($self, $arg_refs) = @_;

  $arg_refs->{orientation}    ||= q{vertical};
  $arg_refs->{side_texts}     ||= [qw(0 end)];
  $arg_refs->{colours}        ||= [qw(grey black yellow red)];

  my $defaults = $arg_refs->{orientation} eq 'vertical' ? $VERTICAL_DEFAULTS
               :                                          $HORIZONTAL_DEFAULTS
               ;

  my $image_height  = $arg_refs->{image_height} || $defaults->{IMAGE_HEIGHT};
  my $image_width   = $arg_refs->{image_width}  || $defaults->{IMAGE_WIDTH};

  my $bar_height    = $arg_refs->{bar_height}   || $defaults->{BAR_HEIGHT};
  my $bar_width     = $arg_refs->{bar_width}    || $defaults->{BAR_WIDTH};

  my $max_pixels = $arg_refs->{orientation} eq 'vertical' ? $bar_height
                 :                                          $bar_width
                 ;

  my $linear_gradient;
  my $cmap = $self->cmap();
  my $colours = $arg_refs->{colours};

  foreach my $color (@{$colours}) {
      push @{$linear_gradient}, [$cmap->rgb_by_name($color)];
  }

  my $im = GD::Image->new($image_width,$image_height);

  my $white = $im->colorAllocate($ALLOCATE_WHITE,$ALLOCATE_WHITE,$ALLOCATE_WHITE);
  $im->transparent($white);

  foreach my $colour (@{$linear_gradient}) {
    $colour = $im->colorAllocate(@{$colour});
  }

  my $all_data_points = $self->give_pixels_a_gradient($im, $max_pixels, $linear_gradient);

  my $gap_width  = $arg_refs->{orientation} eq 'vertical' ? sprintf '%.00f', (($image_width  - $bar_width ) / $QUARTER_DIVISION)
                 :                                          sprintf '%.00f', (($image_width  - $bar_width ) / $HALF_DIVISION)
                 ;

  my $gap_height = $arg_refs->{orientation} eq 'vertical' ? sprintf '%.00f', (($image_height - $bar_height) / $HALF_DIVISION)
                 :                                          sprintf '%.00f', (($image_height - $bar_height) / $QUARTER_DIVISION)
                 ;

  my $num_blocks = scalar @{$arg_refs->{colours}};

  my $block_length = $arg_refs->{orientation} eq 'vertical' ? $bar_height/$num_blocks
                   :                                          $bar_width/$num_blocks;

  $block_length = ceil($block_length/$HALF_DIVISION );

  $arg_refs->{gap_width} = $gap_width;
  $arg_refs->{gap_height} = $gap_height;
  $arg_refs->{block_length} = $block_length;

  $self->draw_text($arg_refs, $im);

  foreach my $i (1..$max_pixels) {

    my ($x1, $x2, $y1, $y2);

    if ($arg_refs->{orientation} eq 'vertical') {
      $x1 = $gap_width;
      $x2 = $x1 + $bar_width;
      $y1 = $gap_height + $i - 1;
      $y2 = $y1 + 1;
    } else {
      $x1 = $gap_width + $i;
      $x2 = $x1 + 1;
      $y1 = $THIRD_DIVISION * $gap_height;
      $y2 = $y1 + $bar_height;
    }

    my $colour = $all_data_points->[$i];

    $im->filledRectangle($x1,$y1,$x2,$y2,$colour);

  }

  #open (FH, ">:raw", 'image.png') || croak 'could not open';print FH $im->png;close FH;

  return $im->png;
}

sub draw_text{

  my ($self, $arg_refs, $im) = @_;
  my $gap_width = $arg_refs->{gap_width};
  my $gap_height = $arg_refs->{gap_height};
  my $block_length = $arg_refs->{block_length};
  my $text_colour = $im->colorAllocate(0,0,0);

  my $texts = $arg_refs->{side_texts};

  if ($arg_refs->{orientation} eq 'vertical') {

    my $text_count = 1;
    foreach my $text (@{$texts}){
       my $x = 2 * $gap_width;
       my $y = $gap_height + $text_count * $block_length ;
       $im->string(gdSmallFont, $x, $y , $text, $text_colour);
       $text_count = $text_count + 2 ;
    }

  } else {

    my $text_count = 1/$THIRD_DIVISION;
    foreach my $text (@{$texts}){
       my $x = ceil($gap_width +$text_count * $block_length );
       my $y = $gap_height;
       $im->string(gdSmallFont, $x, $y, $text, $text_colour);
       $text_count = $text_count + 2 ;
    }

  }
  return;
}
1;

__END__

=head1 NAME

npg::util::image::scale

=head1 VERSION

=head1 SYNOPSIS

  my $oImageScale = npg::util::image::scale->new({});

=head1 DESCRIPTION

Wrapper object to provide a scale image showing the colours in a linear gradient and the min and max values;

=head1 SUBROUTINES/METHODS

=head2 new - constructor to create a graph object

=head2 build_linear_gradient - routine to obtain a scale of colours from given colours. Defaults from black through yellow to red

=head2 plot_scale - plots the scale image. uses defaults if no values provided arrayref of colour names to produce a heat gradient through

  my $png = $oImageScale->plot_scale({
    orientation  => $orientation,
    image_height => $image_height,
    image_width  => $image_width,
    bar_height   => $bar_height,
    bar_width    => $bar_width,
    colours      => [qw(colour1 colour2 colour3...)],
  });
  
=head2 get_legend - plots the legend image, given an array of colours and the same number of texts

=head2 draw_text - draw text for the legend image

=head2 give_pixels_a_gradient - used by plot_scale to assign a colour gradient to a pixel.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

GD
GD::Image
Class::Accessor
npg::util::image::image

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
