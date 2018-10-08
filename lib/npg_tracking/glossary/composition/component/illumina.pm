package npg_tracking::glossary::composition::component::illumina;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;

with qw( npg_tracking::glossary::composition::component
         npg_tracking::glossary::run
         npg_tracking::glossary::lane
         npg_tracking::glossary::subset
         npg_tracking::glossary::tag );

our $VERSION = '0';

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

npg_tracking::glossary::composition::component::illumina

=head1 SYNOPSIS

=head1 DESCRIPTION

Serializable component definition for an Illumina sequencing data - a lane,
lanelet or part of either of them. Defines a set of necessary and sufficient
metadata identifying data from a single Illumina sequencing run on a single
sample or library.

The required attributes are
  (1) id_run, identifying an Illumina run and, implicitly, a flowcell,
  (2) position, identifying the lane of the flowcell.
The optional attributes are
  (1) tag_index, identifying a tag sequence (barcode) that was attached
    to a library (sample) to facilitate its separation during
    analysis from other libraries (samples),
  (2) subset, identifying sequencing reads that, formally speaking,
    belong to a sample, but practically might not be wanted in the final
    data. Example: a bacterial sample from human blood might contain a
    considerable proportion of human DNA, which ends up being sequenced
    alogside the bacterial DNA. During the analysis the bacterial
    and human DNA can be separated by alignment. The human reads are
    described by the same metadata as the 'target' sample, a subset
    attrubute with value 'human' is added. The data before the separation
    is described by the same metadata as 'target' data, a 'subset' attribute
    is set to the value 'all'.

=head1 SUBROUTINES/METHODS

=head2 position

See npg_tracking::glossary::position.

=head2 id_run

See npg_tracking::glossary::run.

=head2 tag_index

An optional tag index that uniquely identifies a component
in a multiplexed lane. See npg_tracking::glossary::tag

=head2 subset

An optional attribute, will default to 'target'.
See npg_tracking::glossary::subset.

=head2 compare_serialized

Compares this object to other illumina component object, see
the parent method in npg_tracking::glossary::composition::component.

=head2 thaw

See thaw() in npg_tracking::glossary::composition::serializable.

=head2 freeze

See freeze() in npg_tracking::glossary::composition::serializable.

=head2 digest

See digest() in npg_tracking::glossary::composition::serializable.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item npg_tracking::glossary::composition::component

=item npg_tracking::glossary::run

=item npg_tracking::glossary::lane

=item npg_tracking::glossary::subset

=item npg_tracking::glossary::tag

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL

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
