#############
# Created By: Marina Gourtovaia
# Created On: 23 June 2010

package npg_tracking::util::db_connect;

use Moose::Role;
with qw/npg_tracking::util::db_config/;

requires qw/ connection storage /;

our $VERSION = '0';

sub _no_connection_info {
    my @info = @_;
    if (!@info) {return 1;}
    if (ref $info[0] eq q[HASH] && !$info[0]->{'dsn'}) {return 1;}
    return 0;
}

around 'connection' => sub {

    my $orig = shift;
    my $self = shift;
    my @info = @_;

    if ( _no_connection_info(@info) && !$self->storage) {
        my $dsn = $self->dsn();
        my $user = $self->dbuser();
        my $pass = $self->dbpass();
        my $attr = $self->dbattr();
        if (@info && ref $info[0] eq q[HASH]) {
            # that is how Catalyst passes db configuration
            $info[0]->{'dsn'}      = $dsn;
            $info[0]->{'user'}     = $user;
            $info[0]->{'password'} = $pass;
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

An example of a non-Moose schema object consuming this role:

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

An example of a Moose schema object consuming this role:

  package npg_tracking::Schema;
  use Moose;
  use MooseX::MarkAsMethods autoclean => 1;
  extends 'DBIx::Class::Schema';
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

=item npg_tracking::util::db_config

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL by Marina Gourtovaia

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
