#############
# Created By: Marina Gourtovaia
# Created On: 23 April 2010

package npg_tracking::glossary::tag;

use Moose::Role;
use Readonly;
use npg_tracking::util::types;

our $VERSION = '0';

Readonly::Scalar our $TAG_DELIM      => q[#];


has 'tag_index'   => (isa        => 'Maybe[NpgTrackingTagIndex]',
                      is         => 'rw',
                      predicate  => 'has_tag_index',
                      required   => 0,
                     );

sub tag_label {
    my $self = shift;
    my $tag_label = defined $self->tag_index ? $TAG_DELIM . $self->tag_index : q[];
    return $tag_label;
}

1;

__END__

=head1 NAME

npg_tracking::glossary::tag

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

tag interface

=head1 SUBROUTINES/METHODS

=head2 tag_index - Tag index. An integer from 0 to 10000. Zero means that no tag has been matched.

=head2 tag_label Tag label as found in file names

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Marina Gourtovaia

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
