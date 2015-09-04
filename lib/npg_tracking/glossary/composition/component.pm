package npg_tracking::glossary::composition::component;

use Moose;
use namespace::autoclean;
use MooseX::StrictConstructor;
use MooseX::Storage;
use Carp;

with Storage( 'traits' => ['OnlyWhenBuilt'],
              'format' => '=npg_tracking::glossary::composition::serializable' );

with qw( npg_tracking::glossary::run
         npg_tracking::glossary::lane
         npg_tracking::glossary::subset
         npg_tracking::glossary::tag );

our $VERSION = '0';

sub compare_serialized {
  my ($self, $other) = @_;

  if (!defined $other) {
    croak 'Object to compare to should be given';
  }
  my $pname = __PACKAGE__;
  my $type = ref $other;
  if (!$type || $type ne $pname) {
    croak qq[Expect object of class $pname to compare to];
  }

  return ($self->freeze cmp $other->freeze);
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

npg_tracking::glossary::composition::component

=head1 SYNOPSIS

=head1 DESCRIPTION

Serializable component (lane, lanelet or part of either of them) definition.

=head1 SUBROUTINES/METHODS

=head2 position

Lane number

=head2 id_run

=head2 tag_index

An optional tag index that uniquely identifies a component
in a multiplexed lane.

=head2 subset

An optional attribute, will default to 'target'.

=head2 compare_serialized

Compares this object to other as JSON serializations. cmp function
is used to compare strings, the outcome of the comparison is returned.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::Storage

=item MooseX::StrictConstructor

=item namespace::autoclean

=item Carp

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
