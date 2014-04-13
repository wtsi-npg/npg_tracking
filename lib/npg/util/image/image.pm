#########
# Author:        ajb
# Created:       2008-08-07
#

package npg::util::image::image;
use strict;
use warnings;
use GD;
use npg::util::image::colourmap;
use base qw(Class::Accessor);
use Carp;
use Readonly;

our $VERSION = '0';

Readonly::Scalar our $MAX_COLOUR_GRADIENTS_SCALE   => 255;
Readonly::Scalar our $MAX_COLOUR_GRADIENTS_HEATMAP => 250;

__PACKAGE__->mk_accessors(qw(cmap colours data_array gradient_array tiles_per_lane image_map_reference data_point_refs gantt_refs));

sub new {
  my ($class, $ref) = @_;
  $ref ||= {};
  bless $ref, $class;

  $ref->{cmap}    ||= npg::util::image::colourmap->new();
  $ref->{colours} ||= [qw(red purple orange blue green yellow magenta cyan)];
  return $ref;
}

sub array_rotate {
  my ($self, $in) = @_;

  my $h = scalar @{$in};
  $h or return [];
  my $w = scalar @{$in->[0]};
  $w or return [];

  my $out = [];

  for my $j (0..$h-1) {
    for my $i (0..$w-1) {
      $out->[$i]       ||= [];
      $out->[$i]->[$j]   = $in->[$j]->[$i];
    }
  }
  return $out;
}

sub build_linear_gradient {
  my ($self, $start_colour, $stop_colour, $steps, $plot_type) = @_;

  my $cmap = $self->cmap();

  if (!$start_colour) {
    $start_colour = ['black','yellow','red'];
    $stop_colour  = undef;
  }

  if (!$steps && $self->data_array()) {
    my $data_array = $self->data_array();
    $steps = scalar@{$data_array} * scalar@{$data_array->[0]};
  }

  $steps = $plot_type && $plot_type eq 'scale' && !$steps    ? $MAX_COLOUR_GRADIENTS_SCALE
         : !$steps || $steps > $MAX_COLOUR_GRADIENTS_HEATMAP ? $MAX_COLOUR_GRADIENTS_HEATMAP
         :                                                     $steps
   ;

  my @gradient_array;
  if (ref$start_colour eq 'ARRAY') {
    @gradient_array = $cmap->build_linear_gradient($steps, $start_colour);
  } else {
    @gradient_array = $cmap->build_linear_gradient($steps, $start_colour, $stop_colour);
  }

  foreach my $gradient (@gradient_array) {
    $gradient = [$cmap->rgb_by_hex($gradient)];
  }

  $self->gradient_array(\@gradient_array);

  return $self->gradient_array();
}

1;
__END__

=head1 NAME

npg::util::image::image

=head1 VERSION

=head1 SYNOPSIS

  my $oDerivedImageObject = npg::util::image::image::<derived_class>->new();

=head1 DESCRIPTION

Base class to provide common functionality for derived image class objects

=head1 SUBROUTINES/METHODS

=head2 new - constructor to create a graph object

=head2 array_rotate - method to change the orientation 90deg of an array of data provided

=head2 build_linear_gradient - method to return a colour gradient scale between two given colours in a number of steps (max 255 for GD). Defaults to black->yellow->red in the number steps equal to number of data fields in your 2d array, to max of 255

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

GD
npg::util::image::colourmap
Class::Accessor

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

