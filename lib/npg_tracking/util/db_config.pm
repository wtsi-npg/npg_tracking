package npg_tracking::util::db_config;

use Moose::Role;
use Carp;
use File::Spec::Functions;
use Config::Auto;

use npg_tracking::util::types;
use npg_tracking::util::config_constants qw/$NPG_CONF_DIR_NAME/;

our $VERSION = '0';

has 'config_file_name'  => (
    isa             => 'Str',
    is              => 'ro',
    required        => 0,
    lazy_build      => 1,
);
sub _build_config_file_name {
    my $self = shift;
    my $config_file_name = ref $self;
    $config_file_name =~ s/::/-/gsmx;
    return $config_file_name;
}

has 'config_file'  => (
    isa             => 'NpgTrackingReadableFile',
    is              => 'ro',
    required        => 0,
    lazy_build      => 1,
    predicate       => 'has_config_file',
    writer          => '_set_config_file',
);
sub _build_config_file {
    my $self = shift;
    my $home = $ENV{'HOME'};
    my $path = $home ? catdir($home, $NPG_CONF_DIR_NAME) : $NPG_CONF_DIR_NAME;
    return catfile ($path, $self->config_file_name);
}

has 'config_data' => (
    is            => 'ro',
    init_arg      => undef,
    isa           => 'HashRef',
    required      => 0,
    lazy_build    => 1,
);
sub _build_config_data {
    my $self = shift;
    my $domain = $ENV{'dev'} || q[live];
    my $config = Config::Auto::parse($self->config_file);
    if (defined $config->{$domain}) {
        $config = $config->{$domain};
    }
    return $config;
}

sub dsn {
    my $self = shift;

    if ($self->config_data->{'dsn'}) {
        return $self->config_data->{'dsn'};
    }
    my $dbname = $self->config_data->{'dbname'};
    if (!$dbname) {
        croak 'No database defined in ' . $self->config_file
    }
    my $dbport = $self->config_data->{'dbport'};
    if(!$dbport) {
        croak 'No port defined in ' . $self->config_file;
    }
    my $dbhost = $self->config_data->{'dbhost'};
    if(!$dbhost) {
        croak 'No host defined in ' . $self->config_file;
    }

    return sprintf 'DBI:mysql:database=%s;host=%s;port=%d',
              $dbname, $dbhost, $dbport;
}

sub dbuser {
    my $self = shift;
    return $self->config_data->{'dbuser'} || q[];
}

sub dbpass {
    my $self = shift;
    return $self->config_data->{'dbpass'} || q[];
}

sub dbattr {
    my $self = shift;
    return $self->config_data->{'dbattr'};
}

1;
__END__

=head1 NAME

npg_tracking::util::db_config

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

 A Moose role for reading NPG database configuration files.

=head1 SUBROUTINES/METHODS

=head2 config_file_name

 An attribute. The name of the configuration file to read.
 Defaults to the class name of the consuming class by
 where :: are replaced with dashes.

=head2 config_file

 An attribute. A path of the configuration file to read.
 Defaults to a file in ${HOME}/.npg directory or, if ${HOME}
 is not defined, to a file in the current directory; the value
 of the config_file_name attribute is used for a file name.

=head2 config_data

 An attribute, cannot be set in the constructor.
 A hash representation of the relevant section of the configuration file
 or all content of configuration file if the section pointed to by the
 dev environment variable is absent.

=head2 dsn

 A methos returning MySQL dsn.

=head2 dbuser

 A method returning the username to be used to connect to the database.

=head2 dbpass

 A method returning the password to be used to connect to the database.

=head2 dbattr

 A method returning the additional connection attributes to be used to connect to the database.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item File::Spec::Functions

=item Config::Auto

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
