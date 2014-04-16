#########
# Author:        Marina Gourtovaia
# Created:       17 April 2013
#

package npg_tracking::daemon::staging;

use Moose;
use Carp;
use English qw(-no_match_vars);
use Readonly;

extends 'npg_tracking::daemon';

our $VERSION = '0';

Readonly::Scalar our $SCRIPT_NAME => q[staging_area_monitor];

has 'root_dir'  => (isa       => 'Str',
                    is        => 'ro',
                    required  => 0,
                    default => q[/export],
                   );

override '_build_hosts' => sub {
    ##no critic (TestingAndDebugging::ProhibitNoWarnings)
    no warnings 'once';
    ##use critic
    require npg_tracking::illumina::run::folder::location;
    my @full_list = map { 'sf' . $_ . '-nfs' }
        @npg_tracking::illumina::run::folder::location::STAGING_AREAS_INDEXES;
    return \@full_list;
};
override 'command'      => sub { my ($self, $host) = @_;
                                 my $sfarea = $self->_host_to_sfarea($host);
                                 return join q[ ], $SCRIPT_NAME, $sfarea;
                               };
override 'daemon_name'  => sub { return $SCRIPT_NAME; };

override 'log_dir' => sub { my ($self, $host) = @_;
                            my $sfarea = $self->_host_to_sfarea($host);
                            my $log_dir = "$sfarea/staging_daemon_logs";

                            return $log_dir;
                          };

=head2 _host_to_sfarea

Convert sfNN-nfs to NN and prefix the root_dir

=cut
sub _host_to_sfarea {
    my ($self, $host) = @_;
    if (!$host) {
      croak q{Need host name};
    }
    (my $sfarea) = $host =~ /^sf(\d+)-nfs$/smx;
    if (!$sfarea) {
      croak qq{Host name $host does not follow expected pattern sfXX-nfs};
     }

    my $root_dir = $self->root_dir;
    return qq[$root_dir/sf$sfarea];
}

no Moose;

1;
__END__

=head1 NAME

npg_tracking::daemon::staging

=head1 SYNOPSIS

=head1 DESCRIPTION

Metadata for a daemon that starts up the analysis script.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English

=item Readonly

=item npg_tracking::illumina::run::folder::location

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

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




