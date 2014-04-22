#########
# Author:        ajb
# Created:       2008-08-07
#
package npg::util::image::heatmap;
use strict;
use warnings;
use GD;
use GD::Image;
use base qw(npg::util::image::image);
use Carp;
use POSIX qw(floor ceil);

our $VERSION = '0';

use Readonly;
Readonly::Scalar our $NUMBER_OF_LANES               => 8;
Readonly::Scalar our $ACCOUNT_FOR_GAP_BETWEEN_LANES => 14;
Readonly::Scalar our $PERCENTAGE_RANGE_MAX          => 100;
Readonly::Scalar our $PERC_ERROR_RANGE_MAX          => 10;
Readonly::Scalar our $ALLOCATE_WHITE                => 255;
Readonly::Scalar our $SPACE_FOR_LANE_NUMBER         => 30;
Readonly::Scalar our $THIRD                         => 3;
Readonly::Scalar our $GREY_COLOR_INDEX              => 105;

Readonly::Hash   our %TILE_LAYOUTS         => {
                                        12  => { TILES_ON_ROW => 12,   ROWS_ON_LANE => 1, TILE_WIDTH => 10 , MIRROR_EVENS => 0, CLUSTER_MAX => 1_500_000, INTENSITY_MAX =>1_000,},
                                        24  => { TILES_ON_ROW => 12,   ROWS_ON_LANE => 2, TILE_WIDTH => 10 , MIRROR_EVENS => 0, CLUSTER_MAX => 1_500_000, INTENSITY_MAX =>1_000,},
                                        32  => { TILES_ON_ROW => 8,   ROWS_ON_LANE => 4, TILE_WIDTH => 10 , MIRROR_EVENS => 0, CLUSTER_MAX => 1_500_000, INTENSITY_MAX =>1_000,},
                                        48  => { TILES_ON_ROW => 8,   ROWS_ON_LANE => 6, TILE_WIDTH => 10 , MIRROR_EVENS => 0, CLUSTER_MAX => 1_500_000, INTENSITY_MAX =>1_000,},
                                        50  => { TILES_ON_ROW => 50,  ROWS_ON_LANE => 1, TILE_WIDTH => 22, MIRROR_EVENS => 0, CLUSTER_MAX => 200_000, INTENSITY_MAX =>1_000,},
                                        96  => { TILES_ON_ROW => 16,  ROWS_ON_LANE => 6, TILE_WIDTH => 10 , MIRROR_EVENS => 0, CLUSTER_MAX => 1_500_000, INTENSITY_MAX =>1_000,},
                                        100 => { TILES_ON_ROW => 50,  ROWS_ON_LANE => 2, TILE_WIDTH => 22, MIRROR_EVENS => 0, CLUSTER_MAX => 200_000, INTENSITY_MAX =>1_000,},
                                        110 => { TILES_ON_ROW => 55,  ROWS_ON_LANE => 2, TILE_WIDTH => 20, MIRROR_EVENS => 0, CLUSTER_MAX => 200_000, INTENSITY_MAX =>1_000,},
                                        120 => { TILES_ON_ROW => 60,  ROWS_ON_LANE => 2, TILE_WIDTH => 18, MIRROR_EVENS => 0, CLUSTER_MAX => 200_000, INTENSITY_MAX =>1_000,},
                                        200 => { TILES_ON_ROW => 100, ROWS_ON_LANE => 2, TILE_WIDTH => 10, MIRROR_EVENS => 0, CLUSTER_MAX => 50_000,  INTENSITY_MAX =>5_000,},
                                        300 => { TILES_ON_ROW => 100, ROWS_ON_LANE => 3, TILE_WIDTH => 10, MIRROR_EVENS => 1, CLUSTER_MAX => 50_000,  INTENSITY_MAX =>5_000,},
                                        330 => { TILES_ON_ROW => 110, ROWS_ON_LANE => 3, TILE_WIDTH => 10, MIRROR_EVENS => 1, CLUSTER_MAX => 50_000, INTENSITY_MAX =>5_000, },
                                      };

sub plot_illumina_map {
  my ($self, $arg_refs) = @_;
  my $data_array = $self->data_array();

  my $tiles_per_lane = $arg_refs->{tiles_per_lane} || $self->tiles_per_lane();

  if (scalar@{$data_array} == $NUMBER_OF_LANES) {
    ($data_array, $tiles_per_lane) = $self->array_to_chip();
  }

  my $height  = scalar@{$data_array};
  my $width   = scalar@{$data_array->[0]};

  my $tile_layout_info = $TILE_LAYOUTS{$tiles_per_lane};

  my $tile_width = $arg_refs->{tile_width} || $tile_layout_info->{TILE_WIDTH};

  $height *= $tile_width;
  $height += $ACCOUNT_FOR_GAP_BETWEEN_LANES;
  $width  *= $tile_width;

  my $im;

  if ($arg_refs->{vertical}) {

    $width += $SPACE_FOR_LANE_NUMBER;

    $im = GD::Image->new($height,$width);
    foreach my $row (@{$data_array}) {
      @{$row} = reverse @{$row};
    }
    $data_array = $self->array_rotate($data_array);

  } else {

    $width += $SPACE_FOR_LANE_NUMBER;
    $im = GD::Image->new($width,$height);

  }

  my $white = $im->colorAllocate($ALLOCATE_WHITE,$ALLOCATE_WHITE,$ALLOCATE_WHITE);
  $im->transparent($white);

  my $data_gradient = $self->get_data_gradient($im, $data_array, $arg_refs, $tile_layout_info);

  my $row_count = 0;
  my $lane_count = 0;
  my $next_lane_count = 0;

  foreach my $row (@{$data_array}) {
    $row_count++;

    if ($arg_refs->{vertical}) {
      $lane_count = 0;
      $next_lane_count = 0;
    } else {
      $next_lane_count++;

      if ($next_lane_count > $tile_layout_info->{ROWS_ON_LANE}) {
        $next_lane_count = 1;
        $lane_count++;
      }

    }


    my $tile_count = 0;
    foreach my $tile (@{$row}) {

      $tile_count++;

      my ($x1,$x2,$y1,$y2);

      if ($arg_refs->{vertical}) {

        $next_lane_count++;
        if ($next_lane_count > $tile_layout_info->{ROWS_ON_LANE}) {
          $next_lane_count = 1;
          $lane_count++;
        }

        $x1 = $tile_width  * ($tile_count - 1) + ($lane_count * 2);
        $x2 = ($tile_width * $tile_count) - 1  + ($lane_count * 2);
        $y1 = $tile_width  * ($row_count  - 1) + $SPACE_FOR_LANE_NUMBER;
        $y2 = ($tile_width * $row_count)  - 1  + $SPACE_FOR_LANE_NUMBER;

      } else {

        $x1 = $tile_width  * ($tile_count - 1) + $SPACE_FOR_LANE_NUMBER;
        $x2 = ($tile_width * $tile_count) - 1  + $SPACE_FOR_LANE_NUMBER;
        $y1 = $tile_width  * ($row_count  - 1) + ($lane_count * 2);
        $y2 = ($tile_width * $row_count)  - 1  + ($lane_count * 2);
      }

      my $value = ref$tile eq 'ARRAY' ? $tile->[0]
                :                       $tile
                ;

      my $colour;
      if ($value) {
        $colour = $data_gradient->{$value};
      } else {
        $colour = 1;
      }
      $im->filledRectangle($x1,$y1,$x2,$y2,$colour);

      if (!$self->image_map_reference()) {
        $self->image_map_reference([]);
      }

      my $tile_number = ref$tile eq 'ARRAY' ? $tile->[1]
                      :                       0
                      ;

      push @{$self->image_map_reference()}, [$x1, $y1, $x2, $y2, {
        position => $lane_count+1,
        tile     => $tile_number,
        value    => $value,
      }];
    }

  }

  my $text_colour = $im->colorAllocate(0,0,0);
  my ($lane_width, $y_position_of_number, $x_position_of_number);

  if ($arg_refs->{vertical}) {
    $lane_width = $height / $NUMBER_OF_LANES;
    $x_position_of_number = $lane_width/$THIRD;
    $y_position_of_number = $SPACE_FOR_LANE_NUMBER/$THIRD;

    foreach my $i (1..$NUMBER_OF_LANES) {

      $im->string(gdSmallFont,$x_position_of_number, $y_position_of_number,$i, $text_colour);

      $x_position_of_number += $lane_width;

    }

  } else {
    $lane_width = $height / $NUMBER_OF_LANES;
    $y_position_of_number = $lane_width/$THIRD;
    $x_position_of_number = $SPACE_FOR_LANE_NUMBER/$THIRD;

    foreach my $i (1..$NUMBER_OF_LANES) {

      $im->string(gdSmallFont,$x_position_of_number, $y_position_of_number,$i, $text_colour);

      $y_position_of_number += $lane_width;

    }

  }

#open (FH, ">:raw", 'image.png') || croak 'could not open';print FH $im->png;close FH;
  return $im->png;
}

sub get_data_gradient{
  my ($self, $im, $data_array, $arg_refs, $tile_layout_info) = @_;
  my $data_gradient = $arg_refs->{gradient_style} && $arg_refs->{gradient_style} eq 'percentage'             ? $self->give_datum_a_range_gradient($im, $data_array, $arg_refs->{colours}, $PERCENTAGE_RANGE_MAX)
                    : $arg_refs->{gradient_style} && $arg_refs->{gradient_style} eq 'percentage_error_rates' ? $self->give_datum_a_range_gradient($im, $data_array, $arg_refs->{colours}, $PERC_ERROR_RANGE_MAX)
                    : $arg_refs->{gradient_style} && $arg_refs->{gradient_style} eq 'cluster'                ? $self->give_datum_a_range_gradient($im, $data_array, $arg_refs->{colours}, $tile_layout_info->{CLUSTER_MAX})
                    : $arg_refs->{gradient_style} && $arg_refs->{gradient_style} eq 'intensity'              ? $self->give_datum_a_range_gradient($im, $data_array, $arg_refs->{colours}, $tile_layout_info->{INTENSITY_MAX})
                    : $arg_refs->{gradient_style} && $arg_refs->{gradient_style} eq 'movez'                  ? $self->get_movez_heatmap_color($im)
                    :                                                                                          $self->give_datum_a_gradient($im, $data_array, $arg_refs->{colours})
                    ;
  return $data_gradient;
}

sub give_datum_a_gradient {
  my ($self, $im, $data_array, $colours) = @_;

  my $linear_gradient = $self->build_linear_gradient($colours);

  foreach my $colour (@{$linear_gradient}) {
    $colour = $im->colorAllocate(@{$colour});
  }

  my $all_data_points={};

  foreach  my $row (@{$data_array}) {
    foreach my $tile (@{$row}) {
      if (ref$tile eq 'ARRAY') {
        if ($tile->[0]) {
          $all_data_points->{$tile->[0]}++;
        }
      } else {
        $all_data_points->{$tile}++;
      }
    }
  }

  my $total_different_values = scalar keys %{$all_data_points};

  my $group_count = $total_different_values/scalar@{$linear_gradient};

  if ($group_count >= 1) {

    $group_count = ceil($group_count);

    my $count = 1;
    my $gradient_index = 0;

    foreach my $tile_value (sort { $a <=> $b } keys %{$all_data_points}) {

      $all_data_points->{$tile_value} = $linear_gradient->[$gradient_index];

      if ($count == $group_count) {
        $count = 1;
        $gradient_index++;
      } else {
        $count++
      }

    }

  } else {
    if ($total_different_values == 0) {
      return $all_data_points;
    }
    $group_count = scalar@{$linear_gradient}/$total_different_values;
    $group_count = floor($group_count);

    my $gradient_index = 0;

    foreach my $tile_value (sort { $a <=> $b } keys %{$all_data_points}) {

      $all_data_points->{$tile_value} = $linear_gradient->[$gradient_index];

      $gradient_index += $group_count;

    }

  }

  return $all_data_points;
}

sub array_to_chip {
  my ($self) = @_;
  my $data_array = $self->data_array();

  my $new_data_array;

  my $tiles = scalar@{$data_array->[0]};

  my $tile_layout_info = $TILE_LAYOUTS{$tiles};

  my $odd_lane = 1;


  foreach my $lane (@{$data_array}) {

    my $count = 1;
    foreach my $tile (@{$lane}) {
      $tile = [$tile, $count];
      $count++;
    }

    if ($tile_layout_info->{MIRROR_EVENS} && !$odd_lane) {

      my @reversed_lane = reverse @{$lane};
      $lane = \@reversed_lane;
      $odd_lane = 1;

    } else {

      $odd_lane = 0;

    }

    my $flip = 0;

    while (my @row = splice @{$lane}, 0, $tile_layout_info->{TILES_ON_ROW}) {

      if ($flip) {
        @row = reverse @row;
      }

      push @{$new_data_array}, \@row;

      $flip = $flip ? 0
            :         1
            ;

    }

  }

  $self->data_array($new_data_array);
  return ($new_data_array, $tiles);
}

sub give_datum_a_range_gradient {
  my ($self, $im, $data_array, $colours, $range_max) = @_;

  my $all_data_points;

  foreach  my $row (@{$data_array}) {
    foreach my $tile (@{$row}) {
      if (ref$tile eq 'ARRAY') {
        if ($tile->[0]) {
          $all_data_points->{$tile->[0]}++;
        }
      } else {
        $all_data_points->{$tile}++;
      }
    }
  }

  my $linear_gradient = $self->build_linear_gradient($colours);

  foreach my $colour (@{$linear_gradient}) {
    $colour = $im->colorAllocate(@{$colour});
  }

  my $gradients = scalar@{$linear_gradient};

  my $group_count = $range_max/$gradients;

  $gradients--;
  my @bin_starts;
  my $bin_start = 0;

  foreach my $i (0..$gradients) {
    push @bin_starts, [$bin_start, $linear_gradient->[$i]];
    $bin_start += $group_count;
  }


  foreach my $tile_value (sort { $a <=> $b } keys %{$all_data_points}) {

    foreach my $i (0..$gradients) {

      my $a = $i + 1;

      if ( $tile_value >= $bin_starts[$i]->[0] && (!$bin_starts[$a] || $tile_value <= $bin_starts[$a]->[0])) {
        $all_data_points->{$tile_value} = $bin_starts[$i]->[1];
        last;
      }

    }
  }

  return $all_data_points;
}

sub get_movez_heatmap_color{
  my ($self, $im) = @_;
  my $red    = $im->colorAllocate($ALLOCATE_WHITE, 0, 0);
  my $black  = $im->colorAllocate(0, 0, 0);
  my $yellow = $im->colorAllocate($ALLOCATE_WHITE, $ALLOCATE_WHITE, 0);
  my $grey   = $im->colorAllocate($GREY_COLOR_INDEX, $GREY_COLOR_INDEX, $GREY_COLOR_INDEX);

  my %movez_heatmap_color = (
                                 0      => $grey,
                                 1      => $black,
                                 2      => $yellow,
                                 $THIRD => $red,
                            );
  return \%movez_heatmap_color;
}

1;

__END__

=head1 NAME

npg::util::image::heatmap

=head1 VERSION

=head1 SYNOPSIS

  my $oImageHeatmap = npg::util::image::heatmap->new({
    data_array     => $2d_data_array,
    tiles_per_lane => $optional_number_of_tiles,
  });

=head1 DESCRIPTION

Wrapper object to provide a generic functionality for creating heatmap images from arrays of data using GD.
If the array is set up with rows in the correct order for a chip, it processes through, but can also cope where
tiles are just provided in order for each lane. Can also generate an image rotated 90deg (eg. view horizontally and vertically).

=head1 SUBROUTINES/METHODS

=head2 new - constructor to create a graph object

=head2 array_rotate - routine to change the orientation 90deg of an array of data provided

=head2 build_linear_gradient - routine to obtain a scale of colours from given colours. Defaults from black through yellow to red

=head2 plot_illumina_map - plots the data_array. the optional number of tiles must be filled in if you send an array that is already ok to the map, can also take a boolean as to whether image should be vertical or horizontal, and an arrayref of colour names to produce a heat gradient through

  my $png = $oImageHeatmap->plot_illumina_map({
    tiles_per_lane => $tiles_per_lane,
    vertical       => $boolVertical,
    colours        => [qw(red blue green yellow)],
    tile_width     => $tile_width,
    gradient_style => $gradient_style,
  });

=head2 give_datum_a_gradient - used by plot_illumina_map to assign a heat colour to the data.

=head2 give_datum_a_range_gradient - used by plot_illumina_map to assign a heat colour to the data, binned by range_max/number of colours in linear gradient scale.

=head2 array_to_chip - used by plot_illumina_map to plot tiles to the correct data structure from 8 * tiles => 16(24) * tiles per row

=head2 get_movez_heatmap_color - return color code for movez heatmap

=head2 get_data_gradient - different color codes based on the input

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
