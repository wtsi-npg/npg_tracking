package npg_tracking::daemon::elembiostaging;

use Moose;
use namespace::autoclean;
use Readonly;

extends 'npg_tracking::daemon';

our $VERSION = '0';

Readonly::Scalar my $SCRIPT_NAME => q[elembio_staging_area_monitor];
Readonly::Array  my @STAGING_AREAS => qw(/lustre/scratch120/elembio/staging);

override 'daemon_name'  => sub { return $SCRIPT_NAME; };
override 'command'      => sub {
  ## no critic (CodeLayout::ProhibitParensWithBuiltins)  
  return sprintf '%s %s',
                 $SCRIPT_NAME,
                 join(q[ ], map { "--staging_area $_"} @STAGING_AREAS);
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

npg_tracking::daemon::elembiostaging

=head1 SYNOPSIS

=head1 DESCRIPTION

Daemon definition for the elembio staging monitor.

Has the same public interface as its parent, C<npg_tracking::daemon>.
C<daemon_name> and C<command> methods are overwritten.

=head1 SUBROUTINES/METHODS

=head2 daemon_name

=head2 command

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Readonly

=item namespace::autoclean

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2025 Genome Research Ltd.

This file is part of NPG software.

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




