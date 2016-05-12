#########
# Author:        David K. Jackson
# Created:       18 December 2009
#

package npg_tracking::daemon::samplesheet;

use Moose;
use Carp;
use English qw(-no_match_vars);
use Readonly;

our $VERSION = '0';

extends 'npg_tracking::daemon';

Readonly::Scalar my $REFERENCE_ROOT => '/nfs/srpipe_references';

override '_build_hosts' => sub { return ['sf49-nfs']; };
##no critic (RequireInterpolationOfMetachars)
override 'command'  => sub { return q[perl -e 'use strict; use warnings; use npg::samplesheet::auto;  use Log::Log4perl qw(:easy); Log::Log4perl->easy_init($INFO); npg::samplesheet::auto->new()->loop();']; };
##use critic
override 'daemon_name'     => sub { return 'npg_samplesheet_daemon'; };
override '_build_env_vars' => sub { return {'NPG_REPOSITORY_ROOT' => $REFERENCE_ROOT}};

no Moose;

1;
__END__

=head1 NAME

npg_tracking::daemon::samplesheet

=head1 SYNOPSIS

=head1 DESCRIPTION

Class for a daemon that generates sample sheets.

=head1 SUBROUTINES/METHODS

=head2 daemon_name

=head2 env_vars

 NPG_REPOSITORY_ROOT env. variable is set for the daemon to
 overwrite the default reference repository on a lustre file
 file system, which is not mounted on the staging areas hosts,
 where this daemon is running by default.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David K. Jackson E<lt>david.jackson@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2009 GRL

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




