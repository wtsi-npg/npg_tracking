package npg_tracking::daemon::staging_local;

use Moose;
use Carp;
use Readonly;
use File::Spec::Functions qw/catdir splitdir/;
use npg_tracking::util::config qw/get_config_staging_areas/;

extends 'npg_tracking::daemon';

our $VERSION = '0';

Readonly::Scalar my $HOST_NAME_SUFFIX  => q[-nfs];

my $config  = get_config_staging_areas();

has [ qw/_local_prefix _prefix/ ]   => (
                    isa        => 'Str',
                    is         => 'ro',
                    required   => 0,
                    lazy_build => 1,
                   );
sub _build__local_prefix {
  my $self = shift;
  return $config->{'prefix'} ||
         croak 'Failed to get path prefix';
}
sub _build__prefix {
  my $self = shift;
  my @components = splitdir $self->_local_prefix;
  # Staging host name prefix is the last component
  # of the local path, e.g. /nfs/sf ,
  my $prefix = pop @components;
  return $prefix || q[];
}

override '_build_hosts' => sub {
  my $self = shift;
  my $indexes = $config->{'indexes'} ||
                croak 'Failed to get list of indexes for staging areas';
  my @full_list = map { $self->_prefix . $_ . $HOST_NAME_SUFFIX } @{$indexes};
  return \@full_list;
};

override 'log_dir'      => sub {
  my ($self, $host) = @_;
  return catdir  $self->host_name2path($host), q[log];
};

sub host_name2path {
  my ($self, $host) = @_;
  if (!$host) {
    croak q[Need host name];
  }
  (my $area) = $host =~ /(\d+)/smx;
  if (!$area) {
    croak qq[Host name $host does not follow expected pattern];
  }
  return $self->_local_prefix . $area;
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

=item Readonly

=item File::Spec::Functions

=item npg_tracking::util::config

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




