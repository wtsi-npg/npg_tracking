# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       14 April 2009
# Last Modified: $Date: 2010-01-13 15:07:25 +0000 (Wed, 13 Jan 2010) $
# Id:            $Id: reference.pm 7844 2010-01-13 15:07:25Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-qc/branches/prerelease-21.0/lib/npg_qc/autoqc/align/reference.pm $
#
package npg_tracking::data::reference;

use strict;
use warnings;
use Moose;

our $VERSION = do { my ($r) = q$Revision: 7844 $ =~ /(\d+)/smx; $r; };

with qw/
          npg_tracking::glossary::run
          npg_tracking::glossary::lane
          npg_tracking::glossary::tag
          npg_tracking::data::reference::find
       /;

__PACKAGE__->meta->make_immutable;
no Moose;

1;
__END__

=head1 NAME

npg_tracking::data::reference

=head1 VERSION

$Revision: 7844 $

=head1 SYNOPSIS

 my $r_user = npg_tracking::data::reference->new(id_run => 22, position => 1);
 my @refs = $r_user->refs();
 my @messages = $r_user->messages->messages;

See npg_tracking::data::reference::find role for a detailed description.

=head1 DESCRIPTION

A wrapper class for npg_tracking::data::reference::find role.
Retrieves a path to a binary, aligner-specific reference sequence for a lane.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item warnings

=item strict

=item Moose

=item npg_tracking::glossary::run

=item npg_tracking::glossary::lane

=item npg_tracking::glossary::tag

=item npg_tracking::data::reference::find

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Marina Gourtovaia

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
