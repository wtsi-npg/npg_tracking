package npg_tracking::glossary::composition::factory::rpt_list;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

our $VERSION = '0';

has 'rpt_list' => (isa           => q[Str],
                   is            => q[ro],
                   required      => 1,
                  );

with 'npg_tracking::glossary::composition::factory::rpt' => {
  component_class => 'npg_tracking::glossary::composition::component::illumina'
};

1;
__END__

=head1 NAME

npg_tracking::glossary::composition::factory::rpt_list

=head1 SYNOPSIS

=head1 DESCRIPTION

A stand-alone class providing a base for classes that get a list of rpt keys
as input (rpt_list string attribute). Has a factory method create_composition
that returns a composition object corresponding to the rpt_list attribute.

=head1 SUBROUTINES/METHODS

=cut

=head2 rpt_list

A string representing a semi-colon separated list of run:position or
run:position:tag strings. This argument is requered. However, this can be
overwritten by a child class if it supplies a suitable builder method.

=head2 create_composition

Returns an instance of npg_tracking::glossary::composition with potentially
multiple npg_tracking::glossary::composition::component::illumina components.
Uses the rpt_list argument as a source of components.
See inflate_rpts subroutine in npg_tracking::glossary::rpt.

  my $composition = $obj->create_composition();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item autoclean

=item npg_tracking::glossary::composition::factory::rpt

=item npg_tracking::glossary::composition::component::illumina

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 GRL

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
