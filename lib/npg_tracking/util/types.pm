#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       20 December 2012
# Last Modified: $Date: 2013-01-08 15:26:40 +0000 (Tue, 08 Jan 2013) $
# Id:            $Id: types.pm 16411 2013-01-08 15:26:40Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/util/types.pm $
#

package npg_tracking::util::types;

use Moose::Util::TypeConstraints;
use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 16411 $ =~ /(\d+)/mxs; $r; };

Readonly::Scalar our $POSITION_MIN  => 1;
Readonly::Scalar our $POSITION_MAX  => 9;
Readonly::Scalar our $TAG_INDEX_MIN => 0;
Readonly::Scalar our $TAG_INDEX_MAX => 999;

subtype 'NpgTrackingReadableFile'
      => as 'Str'
      => where { -r $_ };

subtype 'NpgTrackingExecutable'
      => as 'Str'
      => where { -x $_ };

subtype 'NpgTrackingDirectory'
      => as 'Str'
      => where { -d $_ };

subtype 'NpgTrackingNonNegativeInt'
      => as 'Int'
      => where { $_ >= 0 };

subtype 'NpgTrackingPositiveInt'
      => as 'Int'
      => where { $_ > 0 };

subtype 'NpgTrackingRunId'
      => as 'NpgTrackingPositiveInt';

subtype 'NpgTrackingLaneNumber'
      => as 'Int'
      => where { $_ >= $POSITION_MIN && $_ <= $POSITION_MAX };

subtype 'NpgTrackingTagIndex'
      => as 'Int'
      => where { $_ >= $TAG_INDEX_MIN && $_ <= $TAG_INDEX_MAX };


no Moose::Util::TypeConstraints;

1;
__END__

=head1 NAME

npg_tracking::util::types

=head1 VERSION

$Revision: 16411 $

=head1 SYNOPSIS

=head1 DESCRIPTION

Custom types for npg tracking application.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Util::TypeConstraints

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013 GRL, by Marina Gourtovaia

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
