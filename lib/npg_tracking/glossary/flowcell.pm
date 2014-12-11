package npg_tracking::glossary::flowcell;

use Moose::Role;
use npg_tracking::util::types;

our $VERSION = '0';

=head1 NAME

npg_tracking::glossary::flowcell

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

Illumina flowcell interface

=head1 SUBROUTINES/METHODS

=head2 flowcell_barcode

Manufacturer flowcell barcode/id

=cut

has 'flowcell_barcode' =>  ( isa       => 'Maybe[Str]',
                             is        => 'ro',
                             required  => 0,
);

=head2 flowcell_id

LIMs specific flowcell id

=cut

has 'flowcell_id'      =>  ( isa       => 'Maybe[NpgTrackingPositiveInt]',
                             is        => 'ro',
                             required  => 0,
);

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Genome Research Ltd.

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
