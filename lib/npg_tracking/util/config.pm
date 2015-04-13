#############
# Created By: David K. Jackson
# Created On: 30 March 2015

package npg_tracking::util::config;
use strict;
use warnings;
use Config::Auto;
use Readonly;
use Exporter qw(import);
our @EXPORT_OK = qw(get_config);

our $VERSION = '0';
Readonly::Scalar our $NPG_CONF_DIR => q[.npg];
my ($config_prefix_path) = __FILE__ =~ m{\A(.*)lib/(?:perl.*?/)?npg_tracking/util/config[.]pm\Z}smx;
if (not defined $config_prefix_path) { $config_prefix_path=q(); }
## no critic (Variables::ProhibitPackageVars)
local $Config::Auto::Untaint = 1; #We trust the config file
my ($config) = map{ Config::Auto::parse($_) } grep { -e $_} map { $_.q(/npg_tracking)} ($ENV{'HOME'} ? ($ENV{'HOME'}.q(/).$NPG_CONF_DIR) : ()), $config_prefix_path.q(data);
Readonly::Hash our %CONFIG => %{ $config || {}};

sub get_config { return \%CONFIG; }

1;
__END__

=head1 NAME

npg_tracking::util::config

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

Obtain config details from config files for npg_tracking.

=head1 SUBROUTINES/METHODS

=head2 get_config

  use npg_tracking::util::config;
  my %config = get_config();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

Looks for file npg_tracking in .npg directory below the user's home directory, else below data directory install path

=head1 DEPENDENCIES

=over

=item Readonly

=item Exporter

=item Config::Auto

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David K. Jackson

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL, by David K. Jackson

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
