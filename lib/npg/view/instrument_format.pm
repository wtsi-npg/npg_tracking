package npg::view::instrument_format;

use strict;
use warnings;
use npg::model::instrument_format;

use base qw(npg::view);

our $VERSION = '0';

sub list {
  my $self = shift;
  $self->{'manufacturer'} = $self->util()->cgi()->param('manufacturer');
  $self->{'manufacturer'} ||=
    $npg::model::instrument_format::DEFAULT_MANUFACTURER_NAME;
  return 1;
}

1;

__END__

=head1 NAME

npg::view::instrument_format - view handling for instrument formats

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 list

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item npg::view

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Roger Pettett

=item Marina Gourtovaia

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007-2012,2013,2014,2016,2018,2021,2022,2023,2025 Genome Research Ltd.

This file is part of NPG.

NPG is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/ .

=cut
