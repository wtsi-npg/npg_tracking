#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       11 January 2010
# Last Modified: $Date: 2013-01-23 16:49:39 +0000 (Wed, 23 Jan 2013) $
# Id:            $Id: messages.pm 16549 2013-01-23 16:49:39Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/util/messages.pm $
#

package npg_tracking::util::messages;

use strict;
use warnings;
use Moose;
use MooseX::AttributeHelpers;

our $VERSION    = do { my ($r) = q$Revision: 16549 $ =~ /(\d+)/smx; $r; };

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

$Revision: 16549 $

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

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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

