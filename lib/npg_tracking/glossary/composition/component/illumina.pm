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

sub filename {
  my ($self, $ext) = @_;
  $ext //= q[];
  my $fn = join q[_], $self->id_run, $self->position.$self->tag_label;
  if (defined $self->subset) {
    $fn .= q[_].$self->subset;
  }
  return $fn.$ext;
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

npg_tracking::glossary::composition::component::illumina

=head1 SYNOPSIS

=head1 DESCRIPTION

Serializable component (illumina lane, lanelet or part of either of them) definition.

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

=head2 filename

A standard filename for a component. An optional extension can be specified,
which is appended at the end of the standard filename root as given.

  my $p = 'npg_tracking::glossary::composition::component::illumina';
  my $c = $p->new(id_run => 2, position => 3);
  $c->filename(); # 2_3 is returned
  $c->filename('.fastq'); # 2_3.fastq is returned
  $c->filename('_error_table'); # 2_3_error_table is returned

  $c = $p->new(id_run => 2, position => 3, tag_index => 3);
  $c->filename(); # 2_3#3 is returned
  $c = $p->new(id_run => 2, position => 3, tag_index => undef);
  $c->filename(); # 2_3 is returned

  $c = $p->new(id_run => 2, position => 3, tag_index => 3, subset => 'phix');
  $c->filename(); # 2_3#3_phix is returned
  $c = $p->new(id_run => 2, position => 3, tag_index => undef, subset => 'human');
  $c->filename(); # 2_3_human is returned
  $c = $p->new(id_run => 2, position => 3, tag_index => undef, subset => undef);
  $c->filename('.cram'); # 2_3.cram is returned

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
