#########
# Author:        rmp
# Maintainer:    $Author: gq1 $
# Created:       2006-10-31
# Last Modified: $Date: 2010-05-04 15:28:42 +0100 (Tue, 04 May 2010) $
# Id:            $Id: event_type_subscriber.pm 9207 2010-05-04 14:28:42Z gq1 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg/model/event_type_subscriber.pm $
#
package npg::model::event_type_subscriber;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 9207 $ =~ /(\d+)/smx; $r; };

sub fields {
  return qw(id_event_type_subscriber
            id_event_type
            id_usergroup);
}

1;
__END__

=head1 NAME

npg::model::event_type_subscriber

=head1 VERSION

$LastChangedRevision: 9207 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Carp

=item English -no_match_vars

=item base

=item npg::model

=item strict

=item warnings

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

$Author: Roger M Pettett$

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 GRL, by Roger Pettett

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
