package npg::util::image::scale;
use strict;
use warnings;
use base qw(npg::util::image::image);

our $VERSION = '0';

sub plot_scale {
  my ($self) = @_;
  return $self->simple_image();
}

sub get_legend {
  my ($self) = @_;
  return $self->simple_image();
}

1;

__END__

=head1 NAME

npg::util::image::scale

=head1 SYNOPSIS

=head1 DESCRIPTION

This package is deprecated, it is retained for backward
compatibility with old software. Available methods return
preset static images.

=head1 SUBROUTINES/METHODS

=head2 new

=head2 plot_scale

=head2 get_legend

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 Genome Research Ltd

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
