package npg_tracking::illumina::run::folder::location;

use strict;
use warnings;
use Readonly;

use npg_tracking::util::config qw(get_config_staging_areas);

our $VERSION = '0';

my $config=get_config_staging_areas();

Readonly::Array  our @STAGING_AREAS_INDEXES => @{$config->{'indexes'}||[q()]};
Readonly::Scalar our $STAGING_AREAS_PREFIX  => $config->{'prefix'} || q();
Readonly::Array  our @STAGING_AREAS         => map { $STAGING_AREAS_PREFIX . $_ }
                                               @STAGING_AREAS_INDEXES;
Readonly::Scalar our $HOST_GLOB_PATTERN     => $STAGING_AREAS_PREFIX .
                                               q[{].join(q(,), @STAGING_AREAS_INDEXES).q[}];
Readonly::Scalar our $DIR_GLOB_PATTERN      => q[{IL,HS}*/*/];
Readonly::Scalar our $FOLDER_PATH_PREFIX_GLOB_PATTERN => "$HOST_GLOB_PATTERN/$DIR_GLOB_PATTERN";

1;

__END__

=head1 NAME

npg_tracking::illumina::run::folder::location

=head1 SYNOPSIS 

=head1 DESCRIPTION

Externally accessible constants.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David K. Jackson

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
