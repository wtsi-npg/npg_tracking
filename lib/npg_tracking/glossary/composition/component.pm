package npg_tracking::glossary::composition::component;

use Moose::Role;
use namespace::autoclean;
use MooseX::Storage;
use Carp;

with Storage( 'traits' => [qw/OnlyWhenBuilt DisableCycleDetection/],
              'format' => '=npg_tracking::glossary::composition::serializable' );

our $VERSION = '0';

sub compare_serialized {
  my ($self, $other) = @_;

  if (!defined $other) {
    croak 'Object to compare to should be given';
  }
  my $pname = ref $self;
  my $type  = ref $other;
  if (!$type || $type ne $pname) {
    croak qq[Expect object of class $pname to compare to];
  }

  return ($self->freeze cmp $other->freeze);
}

no Moose::Role;
1;
__END__

=head1 NAME

npg_tracking::glossary::composition::component

=head1 SYNOPSIS

=head1 DESCRIPTION

A Moose role defining a common interface for a component, which can be
a part of a composition, see npg_tracking::glossary::camposition.

A component defines a set of necessary and sufficient metadata identifying
data from a single experiment on a single sample or library. This interface
does not define any metadata, they should be defined by a class consuming
this role. The role provides methods that every component should implement
in order to be a part of a composition.

See npg_tracking::glossary::composition::component::illumina for an
implementation of Illumina sequencing specific component.

=head1 SUBROUTINES/METHODS

=head2 compare_serialized

Compares this object to other object of the same type as JSON serializations.
'cmp' function is used, the outcome of the comparison is returned.

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

=item Moose::Role

=item MooseX::Storage

=item namespace::autoclean

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015,2021 Genome Research Ltd.

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
