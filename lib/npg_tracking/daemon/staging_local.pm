package npg_tracking::daemon::staging_local;

use Moose;
use Carp;
use File::Spec::Functions;
use npg_tracking::illumina::run::folder::location;

extends 'npg_tracking::daemon';

our $VERSION = '0';

has 'root_dir'  => (isa       => 'Str',
                    is        => 'ro',
                    required  => 0,
                    default => q[/export],
                   );

override '_build_hosts' => sub {
  ##no critic (TestingAndDebugging::ProhibitNoWarnings)
  no warnings 'once';
  my @full_list = map { 'sf' . $_ . '-nfs' }
      @npg_tracking::illumina::run::folder::location::STAGING_AREAS_INDEXES;
  return \@full_list;
};

override 'log_dir'      => sub {
  my ($self, $host) = @_;
  return catdir  $self->host_name2path($host), $self->daemon_name . q[_logs];
};

sub host_name2path {
  my ($self, $host) = @_;
  if (!$host) {
    croak q{Need host name};
  }
  (my $sfarea) = $host =~ /^sf(\d+)-nfs$/smx;
  if (!$sfarea) {
    croak qq{Host name $host does not follow expected pattern sfXX-nfs};
  }
  return catdir $self->root_dir, q{sf}.$sfarea;
}

no Moose;

1;
__END__

=head1 NAME

npg_tracking::daemon::staging_local

=head1 SYNOPSIS

=head1 DESCRIPTION

  Base class for daemons running locally on staging areas.

=head1 SUBROUTINES/METHODS

=head2 host_name2path

  Convert staging server host name to a local path on a staging server.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item File::Spec::Functions

=item npg_tracking::illumina::run::folder::location

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 GRL, by Marina Gourtovaia

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




