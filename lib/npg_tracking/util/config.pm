#############
# Created By: David K. Jackson
# Created On: 30 March 2015

package npg_tracking::util::config;
use strict;
use warnings;
use Config::Auto;
use Readonly;
use Exporter qw(import);
use npg_tracking::util::config_constants qw($NPG_CONF_DIR_NAME);

our @EXPORT_OK = qw(get_config
                    get_config_repository
                    get_config_staging_areas);

our $VERSION = '0';

my ($config_prefix_path) = __FILE__ =~ m{\A(.*)lib/(?:perl.*?/)?npg_tracking/util/config[.]pm\Z}smx;
if (not defined $config_prefix_path) { $config_prefix_path=q(); }
## no critic (Variables::ProhibitPackageVars)
local $Config::Auto::Untaint = 1; #We trust the config file
my ($config) = map{ Config::Auto::parse($_) } grep { -e $_} map { $_.q(/npg_tracking)} ($ENV{'HOME'} ? ($ENV{'HOME'}.q(/).$NPG_CONF_DIR_NAME) : ()), $config_prefix_path.q(data);
Readonly::Hash our %CONFIG => %{ $config || {}};

sub get_config { return \%CONFIG; }

sub get_config_staging_areas { return $CONFIG{'staging_areas'} || {}; };

sub get_config_repository { return $CONFIG{'repository'} || {}; };

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

  use npg_tracking::util::config qw/get_config/;
  my $config = get_config()->{'some_key'};

=head2 get_config_staging_areas

A shortcut to staging areas configuration. Returns a hash reference
containing further configuration entries or an empty hash.

  use npg_tracking::util::config qw/get_config_staging_areas/;
  my $prefix = get_config_staging_areas()->{'prefix'};

=head2 get_config_repository

A shortcut to repository (for references and similar) configuration.
Returns a hash reference containing further configuration entries or an empty hash.

  use npg_tracking::util::config qw/get_config_repository/;
  my $iprefix = get_config_repository()->{'instrument_prefix'};

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

Looks for file npg_tracking in .npg directory below the user's home directory,
else below data directory install path.

=head1 DEPENDENCIES

=over

=item strict

=item warnongs

=item Readonly

=item Exporter

=item Config::Auto

=item npg_tracking::util::config_constants

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
