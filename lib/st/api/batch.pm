#########
# Author:        rmp
# Created:       2007-03-28
#
package st::api::batch;
use base qw(st::api::base);
use strict;
use warnings;

__PACKAGE__->mk_accessors(fields());

our $VERSION = '0';


sub live {
    my $self = shift;
    return $self->live_url()  . q{/batches};
}

sub dev {
    my $self = shift;
    return $self->dev_url()   . q{/batches};
}

sub fields { return qw(id); }

1;
__END__

=head1 NAME

st::api::batch - an interface to Sample Tracking batches

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - fields in this package

  These all have default get/set accessors.

  my @aFields = $oBatch->fields();
  my @aFields = <pkg>->fields();

=head2 dev - development service URL

  my $sDevURL = $oBatch->dev();

=head2 live - live service URL

  my $sLiveURL = $oBatch->live();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item st::api::base

=item strict

=item warnings

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 GRL, by Roger Pettett

This file is part of NPG.

NPG is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/ .

=cut
