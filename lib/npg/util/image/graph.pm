#########
# Author:        rmp
# Created:       2008-06-10
#
package npg::util::image::graph;
use strict;
use warnings;
use GD::Graph::lines;
use GD::Graph::bars;
use GD::Graph::area;
use GD::Graph::mixed;
use GD;
use base qw(npg::util::image::image);
use Carp qw(carp croak cluck confess);
use Readonly;

our $VERSION = '0';

Readonly our $THREE          => 3;
Readonly our $FOUR           => 4;
Readonly our $WIDTH          => 400;
Readonly our $HEIGHT         => 200;
Readonly our $COLOR_ALLOCATE => 240;
Readonly our $LEGEND_FONT_SIZE => 10;

sub plotter {
  my ($self, $data, $attrs, $type, $no_rotate) = @_;

  $type            ||= 'lines';
  $attrs           ||= {};
  $attrs->{legend} ||= [];

  my $width  = $attrs->{width}  || $WIDTH;
  my $height = $attrs->{height} || $HEIGHT;

  if(!$data || ref$data ne 'ARRAY' || !scalar @{$data}) {

    my $title = "No @{[$attrs->{title}||q()]} Data";
    my $gd    = GD::Image->new($width, $height);
    $gd->colorAllocate($COLOR_ALLOCATE,$COLOR_ALLOCATE,$COLOR_ALLOCATE);
    my $blk   = $gd->colorAllocate(0,0,0);
    $gd->string(gdSmallFont,
               $width/2 - (length $title) * $THREE,
               $height/2 - $FOUR,
               $title,
               $blk);
    return $gd->png();
  }
  my $cmap = $self->cmap();
  my $gtype = "GD::Graph::$type";
  my $graph = $gtype->new($width, $height);

  $graph->set(
              dclrs        => [
                              map {
                                GD::Graph::colour::add_colour(q(#).$cmap->hex_by_name($_));
                              } @{$self->colours()}
                              ],
              fgclr        => 'lgray',
              boxclr       => 'white',
              accentclr    => 'black',
              shadowclr    => 'black',
              y_long_ticks => 1,
              %{$attrs},
             );
  if($type eq q[lines]) {$graph->set(line_width => 2);}

  if(scalar @{$attrs->{legend}}) {
    $graph->set_legend(@{$attrs->{legend}});
    $graph->set_legend_font(
        ['verdana', 'arial', gdMediumBoldFont], $LEGEND_FONT_SIZE )
  }

  if (!$no_rotate) {
    $data = $self->array_rotate($data);
  }
  my $png;

  eval { $png = $graph->plot($data)->png(); 1; } or do { croak $graph->error(); };
  if (!$self->data_point_refs()) {
    $self->data_point_refs([]);
  }

  eval {
    push @{$self->data_point_refs()}, $graph->get_hotspot();
    1;
  } or do { carp 'could not get hotspot'; };

  if ($attrs->{return_object}) {
    return $graph->plot($data);
  }

  return $png;
}


1;

__END__

=head1 NAME

npg::util::image::graph

=head1 VERSION

=head1 SYNOPSIS

  my $oImageGraph = npg::util::image::graph->new();

=head1 DESCRIPTION

Wrapper object to provide a generic functionality for creating graphs from arrays of data using GD::Graph

=head1 SUBROUTINES/METHODS

=head2 new - constructor to create a graph object

=head2 array_rotate - routine to change the orientation 90deg of an array of data provided

=head2 plotter - handler to plot the graph. takes a number of arguments, and outputs a png graph image

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

GD::Graph::lines
GD::Graph::bars
GD::Graph::area
GD::Graph::mixed
GD
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
