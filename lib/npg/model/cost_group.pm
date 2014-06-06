#########
# Author:        ajb
# Created:       2011-08-15
#
package npg::model::cost_group;
use strict;
use warnings;
use English qw(-no_match_vars);
use Carp;
use base qw(npg::model);
our $VERSION = '0';

use npg::model::cost_code;

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_all();
__PACKAGE__->has_many([qw{cost_code}]);

sub fields {
  return qw{
    id_cost_group
    name
  };
}

sub init {
  my $self = shift;

  if ( ! $self->{id_cost_group} && $self->{name} ) {
    my $query = q(SELECT id_cost_group
                  FROM   cost_group
                  WHERE  name = ?);
    my $ref   = [];

    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->name());
    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{id_cost_group} = $ref->[0]->[0];
    }
  }

  return $self;
}

sub group_codes {
  my ( $self ) = @_;

  my $codes;
  @{ $codes } = @{ $self->cost_codes() };

  foreach my $code ( @{ $codes } ) {
    $code = $code->cost_code();
  }

  return $codes;
}

1;
__END__

=head1 NAME

npg::model::cost_group

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields

list of the database table columns

=head2 init

enable instantiation of object with the name of the group

=head2 group_codes

returns an arrayref containing just the codes associated with the group (not objects)

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item English

=item Carp

=item base

=item npg::model

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown

=head1 LICENSE AND COPYRIGHT

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
