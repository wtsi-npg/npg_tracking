#############
# Created By: Marina Gourtovaia
# Created On: 23 June 2010

package npg_tracking::util::db_connect;

use Moose::Role;
use Carp;
use File::Spec::Functions;
use Config::Auto;
use Readonly;
use npg_tracking::util::types;

requires qw/ connection storage /;

our $VERSION = '0';

Readonly::Scalar my $NPG_CONF_DIR => q[.npg];

has '_config_file'  => (
    isa             => 'NpgTrackingReadableFile',
    is              => 'ro',
    required        => 0,
    lazy_build      => 1,
);
sub _build__config_file {
    my $self = shift;
    my $home = $ENV{'HOME'};
    my $path = $home ? catdir($home, $NPG_CONF_DIR) : $NPG_CONF_DIR;
    my $config_file_name = ref $self;
    $config_file_name =~ s/::/-/gsmx;
    return catfile ($path, $config_file_name);
}


has '_config_data' => (
    is            => 'ro',
    init_arg      => undef,
    isa           => 'HashRef',
    required      => 0,
    lazy_build    => 1,
);
sub _build__config_data {
    my $self = shift;
    my $domain = $ENV{'dev'} || q[live];
    my $config = Config::Auto::parse($self->_config_file);
    if (defined $config->{$domain}) {
        $config = $config->{$domain};
    }
    return $config;
}

sub _dsn {
    my $self = shift;

    if ($self->_config_data->{'dsn'}) {
        return $self->_config_data->{'dsn'};
    }
    my $dbname = $self->_config_data->{'dbname'};
    if (!$dbname) {
        croak 'No database defined in ' . $self->_config_file
    }
    my $dbport = $self->_config_data->{'dbport'};
    if(!$dbport) {
        croak 'No port defined in ' . $self->_config_file;
    }
    my $dbhost = $self->_config_data->{'dbhost'};
    if(!$dbhost) {
        croak 'No host defined in ' . $self->_config_file;
    }

    return sprintf 'DBI:mysql:database=%s;host=%s;port=%d',
              $dbname, $dbhost, $dbport;
}

sub _dbuser {
    my $self = shift;
    return $self->_config_data->{'dbuser'} || q[];
}

sub _dbpass {
    my $self = shift;
    return $self->_config_data->{'dbpass'} || q[];
}

sub _dbattr {
    my $self = shift;
    return $self->_config_data->{'dbattr'};
}

sub _no_connection_info {
    my @info = @_;
    if (!@info) {return 1;}
    if (ref $info[0] eq q[HASH] && !$info[0]->{dsn}) {return 1;}
    return 0;
}


around 'connection' => sub {

    my $orig = shift;
    my $self = shift;
    my @info = @_;

    if ( _no_connection_info(@info) && !$self->storage) {
        my $dsn = $self->_dsn();
        my $user = $self->_dbuser();
        my $pass = $self->_dbpass();
        my $attr = $self->_dbattr();
        if (@info && ref $info[0] eq q[HASH]) {
            # that is how Catalyst passes db configuration
            $info[0]->{dsn} = $dsn;
            $info[0]->{user} = $user;
            $info[0]->{password} = $pass;
            if ($attr and ref $attr eq q[HASH]) {
              %{$info[0]} = (%{$info[0]}, %{$attr});
            }
        } else {
            @info = ($dsn, $user, $pass, $attr);
        }
    }

    return $self->$orig(@info);
};

1;
__END__

=head1 NAME

npg_tracking::util::db_connect

=head1 VERSION

=head1 SYNOPSIS

An example of a schema object consuming this role:

  package npg_tracking::Schema;
  use base 'DBIx::Class::Schema';
  __PACKAGE__->load_namespaces(
    result_namespace => 'Result',
  );
  BEGIN {
    use Moose;
    use MooseX::NonMoose;
    extends 'DBIx::Class::Schema';
  }
  with qw/npg_tracking::util::db_connect/;


=head1 DESCRIPTION

A Moose role that has a modifier method for the connection method of
a class that inherits from DBIx::Class::Schema. If the connect method
of such a class is invoked without attributes, this method tries
to retrieve database dsn string, username and password from a
configuration file.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Readonly

=item Carp

=item File::Spec::Functions;

=item Config::Auto

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

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
