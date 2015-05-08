package npg_tracking::util::config_constants;

use strict;
use warnings;
use Readonly;
use Exporter qw(import);

our @EXPORT_OK = qw/$NPG_CONF_DIR_NAME/;

our $VERSION = '0';

Readonly::Scalar our $NPG_CONF_DIR_NAME => q[.npg];

1;
__END__

=head1 NAME

npg_tracking::util::config_constants

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

Contains definitions for shared constant variables.

Exports $NPG_CONF_DIR_NAME variable - the name of the directory for NPG configuration files.

=head1 SUBROUTINES/METHODS
 
=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Readonly

=item Exporter

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL, by Marina Gourtovaia

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
