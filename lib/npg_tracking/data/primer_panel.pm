package npg_tracking::data::primer_panel;

use Moose;

our $VERSION = '0';

extends 'npg_tracking::data::reference';
with    'npg_tracking::data::primer_panel::find';

__PACKAGE__->meta->make_immutable;
no Moose;

1;
__END__

=head1 NAME

npg_tracking::data::primer_panel

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

A wrapper class for finding the location of primer panel related files.

=head1 SUBROUTINES/METHODS

=head2 id_run

=head2 position

=head2 tag_index

=head2 rpt_list

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item npg_tracking::data::reference

=item npg_tracking::data::primer_panel::find

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2020 GRL

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
