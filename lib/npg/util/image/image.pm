package npg::util::image::image;

use strict;
use warnings;
use GD::Image;
use base qw(Class::Accessor);
use Readonly;

our $VERSION = '0';

Readonly our $WIDTH  => 40;
Readonly our $HEIGHT => 20;

sub new {
  my ($class, $ref) = @_;
  $ref ||= {};
  bless $ref, $class;
  return $ref;
}

sub simple_image {
  return GD::Image->new($WIDTH, $HEIGHT)->png();
}

1;
__END__

=head1 NAME

npg::util::image::image

=head1 SYNOPSIS

=head1 DESCRIPTION

This package is deprecated, it is retained for backward
compatibility with old software. Available methods return
preset static images.

=head1 SUBROUTINES/METHODS

=head2 new

=head2 simple_image

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item Class::Accessor

=item GD::Image

=item Readonly

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

