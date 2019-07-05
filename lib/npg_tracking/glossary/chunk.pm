package npg_tracking::glossary::chunk;

use Moose::Role;

our $VERSION = '0';

=head1 NAME

npg_tracking::glossary::chunk

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

Sequence chunk definition.
Anticipated use:
  - Integer denoting chunk number starting from 1. 

=head1 SUBROUTINES/METHODS

=head2 chunk

=cut

has 'chunk' =>  ( isa       => 'Maybe[Int]',
                  is        => 'ro',
                  predicate => 'has_chunkt',
                  required  => 0,
);

no Moose::Role;

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovai
Martin Pollard

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015, 2019 Genome Research Ltd.

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
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
