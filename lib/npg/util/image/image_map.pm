#########
# Author:        ajb
# Created:       2008-09-01
#
package npg::util::image::image_map;
use strict;
use warnings;
use base qw(Class::Accessor);
use Carp;

our $VERSION = '0';

use Readonly;
Readonly::Scalar our $MAX_COORDINATES  => 3;
Readonly::Scalar our $RETURN_FROM_GD_GRAPH_X1 => 0;
Readonly::Scalar our $RETURN_FROM_GD_GRAPH_Y1 => 1;
Readonly::Scalar our $RETURN_FROM_GD_GRAPH_X2 => 2;
Readonly::Scalar our $RETURN_FROM_GD_GRAPH_Y2 => 3;

__PACKAGE__->mk_accessors(qw(image_refs));


sub new {
  my ($class, $ref) = @_;
  $ref ||= {};
  bless $ref, $class;

  return $ref;
}

sub render_map {
  my ($self, $arg_refs) = @_;

  my $data = $arg_refs->{data};
  my $image_url  = $arg_refs->{image_url};
  my $map = qq[<map name="$arg_refs->{id}">\n];
  for my $box (@{$data}) {
    my $data_information = pop@{$box};
    my $url = $data_information->{url} || q{#};
    my $title;
    foreach my $key (sort keys %{$data_information}) {
      next if $key eq 'url';
      my $name = ucfirst$key;
      my $value = $data_information->{$key} || q{};
      $title .= "$name:$value "
    }
    $map .= qq[<area coords="(@{$box})[0..$MAX_COORDINATES]" href="$url" title="$title" />];
  }
  $map .= qq[</map><img src="$image_url" usemap="#$arg_refs->{id}"/>];

  return $map;
}

sub process_instrument_gantt_values {
  my ($self, $arg_refs) = @_;
  my @real_data_point_sets;
  foreach my $dpr (@{$arg_refs->{data_points}}) {
    if ($dpr) {
      push @real_data_point_sets, $dpr;
    }
  }
  my $number_of_data_point_sets      = scalar@real_data_point_sets;
  my $number_of_instrument_data_sets = scalar@{$arg_refs->{data_values}};

  if ($number_of_data_point_sets != $number_of_instrument_data_sets) {
    croak "Inconsistent number of data point sets -\n\timage: $number_of_data_point_sets\n\tinstrument: $number_of_instrument_data_sets\n\n";
  }

  my $data_point_sets = $self->_array_rotate(\@real_data_point_sets);
  my $instrument_sets = $self->_array_rotate($arg_refs->{data_values});
  my @boxes;
  my $previous_box;
  foreach my $i (0..(scalar@{$data_point_sets} - 1)) {
    foreach my $ii (0..(scalar@{$data_point_sets->[$i]} -1)) {
      next if $ii%2 == 1;
      my $box_info = [];
      my $next = $ii+1;
      shift @{$data_point_sets->[$i]->[$ii]};   # gets rid of the shape
      shift @{$data_point_sets->[$i]->[$next]}; # gets rid of the shape
      push @{$box_info}, $data_point_sets->[$i]->[$ii]->[$RETURN_FROM_GD_GRAPH_X1];
      push @{$box_info}, $data_point_sets->[$i]->[$ii]->[$RETURN_FROM_GD_GRAPH_Y1];
      push @{$box_info}, $data_point_sets->[$i]->[$ii]->[$RETURN_FROM_GD_GRAPH_X2];
      push @{$box_info}, $data_point_sets->[$i]->[$next]->[$RETURN_FROM_GD_GRAPH_Y1];
      my $start;
      my $end;
      if ($arg_refs->{convert}) {
        $start = $arg_refs->{convert}($instrument_sets->[$i]->[$next]);
        $end   = $arg_refs->{convert}($instrument_sets->[$i]->[$ii]);
      } else {
        $start = $instrument_sets->[$i]->[$next];
        $end   = $instrument_sets->[$i]->[$ii];
      }
      my $title = qq{Start:$start, End:$end};
      my $href = {};
      if ($arg_refs->{additional_info}) {
        $href->{$arg_refs->{additional_info}} = qq{$title};
      } else {
        $href->{title} = $title
      }
      push @{$box_info}, $href;
      if (!$previous_box) {
        $previous_box = $box_info;
        push @boxes, $box_info;
        next;
      }
      foreach my $ti (0..(scalar@{$previous_box} - 2)) {
        if ($previous_box->[$ti] != $box_info->[$ti]) {
          push @boxes, $box_info;
          $previous_box = $box_info;
          last;
        }
      }
    }
  }

  return \@boxes;
}

sub _array_rotate {
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

1;

__END__

=head1 NAME

npg::util::image::image_map

=head1 VERSION

=head1 SYNOPSIS

  my $oImageMap = npg::util::image::image_map->new();

=head1 DESCRIPTION

Class to provide an image map reference to overlay an image (likely heatmaps)

=head1 SUBROUTINES/METHODS

=head2 new - constructor to create an image_map object

=head2 render_map - renders the data points and id into a html map for use in front of the image. For the data sets, you must have a hash, the key value pairs for a title for the image space

  my $sRenderMap = $oImageMap->render_map($arg_refs);

  $arg_refs = {
    data => [[$x1,$y1,$x2,$y2,{url => $a_url, other_key_value_pairs}],..],
    image_url => $url_of_image_map_is_for,
    id => $unique_id_for_map,
  };

=head2 process_instrument_gantt_values - organises gantt point data into format to be passed to render_map

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

Class::Accessor
Readonly
Carp
strict
warnings

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
