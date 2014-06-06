#########
# Author:        Marina Gourtovaia
# Created:       11 January 2010
#

package npg_tracking::util::messages;

use strict;
use warnings;
use Moose;
use MooseX::AttributeHelpers;

our $VERSION = '0';

has 'mlist' => (
      metaclass => 'Collection::Array',
      is        => 'ro',
      isa       => 'ArrayRef[Str]',
      default   => sub { [] },
      provides  => {
          'push'     => 'push',
          'pop'      => 'pop',
          'count'    => 'count',
          'empty'    => 'empty',
          'clear'    => 'clear',
          'elements' => 'messages',
      },
                 );
no Moose;

1;
__END__

=head1 NAME

npg_tracking::util::messages

=head1 VERSION

=head1 SYNOPSIS

 my $mlist = npg_tracking::util::messages->new();
 $mlist->push(q[new message]); # add a new message
 $mlist->pop();      # remove and return the last message
 $mlist->count();    # number of messages
 $mlist->empty();    # true if the list empty, otherwise false
 $mlist->clear();    # clears the list
 $mlist->messages(); # a list of all messages

=head1 DESCRIPTION

A message list (queue). 

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item warnings

=item strict

=item Moose

=item MooseX::AttributeHelpers

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2009 GRL, by Marina Gourtovaia

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

