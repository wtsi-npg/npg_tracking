#########
# Author:        David K. Jackson
# Created:       18 December 2009
# copied from: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/instrument_handling/branches/prerelease-16.0/lib/srpipe/runner/analysis.pm, r15456
#

package npg_tracking::daemon::samplesheet;

use Moose;
use Carp;
use English qw(-no_match_vars);
use Readonly;

extends 'npg_tracking::daemon';

override '_build_hosts' => sub { return ['sf-4-1-02']; };
##no critic (RequireInterpolationOfMetachars)
override 'command'  => sub { return $EXECUTABLE_NAME . q[ -e 'use strict; use warnings; use npg::samplesheet::auto;  use Log::Log4perl qw(:easy); BEGIN{ Log::Log4perl->easy_init({level=>$INFO,}); } npg::samplesheet::auto->new()->loop();']; };
##use critic
override 'daemon_name'  => sub { return 'npg_samplesheet_daemon'; };

if ( $ENV{PERL5LIB} ) {
  my @p5libs = split /:/smx, $ENV{PERL5LIB};
  has '+libs' => ( default => sub {return \@p5libs; }, );
}

no Moose;

1;
__END__

=head1 NAME

npg_tracking::daemon::samplesheet

=head1 SYNOPSIS

=head1 DESCRIPTION

Class for a daemon that generates sample sheets.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: David K. Jackson E<lt>david.jackson@sanger.ac.ukE<gt>

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




