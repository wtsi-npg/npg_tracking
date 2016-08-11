#########
# Author:        ajb
# Created:       2009-02-05
#
package npg::view::instrument_utilisation;
use base qw(npg::view);
use strict;
use warnings;

our $VERSION = '0';

sub authorised {
  my ($self, @args) = @_;
  my $requestor = $self->util->requestor();

  if ($requestor->username() eq 'pipeline') {
    return 1;
  }
  return $self->SUPER::authorised(@args);
}

1;

__END__

=head1 NAME

npg::view::instrument_utilisation - view handling for instrument_utilisation

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 authorised - added authorization to allow pipeline to CRUD

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item npg::view

=item strict

=item warnings

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown, E<lt>ajb@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 GRL

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
