package t::ftp_util;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use English qw(-no_match_vars);
use File::chdir;
use File::Temp qw(tempfile);
use Moose;
use Test::TCP;
use Test::FTP::Server;
use Readonly;

Readonly::Scalar my $SIGKILL => 9;

Readonly::Hash my %DEFAULT => (
    allow_anon  => 1,
    error_log   => $CWD . '/ERR.LOG',
    daemon_mode => 1,
    debug       => 1,
    pass        => 'testpass',
    port        => 2243,
    root        => $CWD . '/t/data',
    run_in_bg   => 1,
    syslog      => 0,
    user        => 'testuser',
);


foreach my $attr ( keys %DEFAULT ) {
    has $attr => (
        is      => 'ro',
        isa     => 'Str',
        default => $DEFAULT{$attr},
    );
}


has args => (
    is         => 'ro',
    isa        => 'ArrayRef',
    lazy_build => 1,
);


has config_file => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);


sub _build_args {
    my ($self) = @_;

    my $args = [
        'users' => [
            {
                'user' => $self->user(),
                'pass' => $self->pass(),
                'root' => $self->root(),
            }
        ],
        'ftpd_conf' => {
            'allow anonymous'   => 1,
            'daemon mode'       => 1,
            'enable syslog'     => 0,
            'port'              => $self->port(),
            'run in background' => 0,
        },

     #   '-C' => $self->config_file(), #Uncomment if dumping Test::FTP::Server
    ];


    return $args;
}

# We don't need this right now, but will if we replace Test::FTP::Server
sub _build_config_file {
    my ($self) = @_;

    my ( $fh, $filename ) = tempfile( undef, UNLINK => 1 );

    printf {$fh} "allow anonymous: %s\n",   $self->allow_anon();
    printf {$fh} "daemon mode: %s\n",       $self->daemon_mode();
    printf {$fh} "debug: %s\n",             $self->debug();
    printf {$fh} "error log: %s\n",         $self->error_log();
    printf {$fh} "port: %s\n",              $self->port();
    printf {$fh} "run in background: %s\n", $self->run_in_bg();
    printf {$fh} "enable syslog: %s\n",     $self->syslog();

    return $filename;
}


sub start {
    my ($self) = @_;

    my $child_pid;
    if ( !defined( $child_pid = fork ) ) {
        croak "Cannot fork: $OS_ERROR";
    }

    elsif ( $child_pid == 0 ) {

        my $server = Test::FTP::Server->new( @{ $self->args() } );
        exec $server->run() or croak "Failed to start ftp server: $OS_ERROR";

    }

    return $child_pid;
}


sub stop {
    my ( $self, $pid ) = @_;
    kill $SIGKILL, $pid;
    return;
}


no Moose;
__PACKAGE__->meta->make_immutable();
1;


__END__


=head1 NAME

t::ftp_util - a mock FTP server to run tests against.

=head1 VERSION

=head1 SYNOPSIS

    C<<use t::ftp_util;

       my $ftp = t::ftp_util->new();
       my $pid = $ftp->start();

       # Do some ftp-based testing

       $ftp->stop($pid);>>

=head1 DESCRIPTION

This is a Moose-based wrapper around L<Test::FTP::Server>, using some default
values along with accessors to over-ride them. Also a stop() method has been
added.

Use it as per the SYNOPSIS but you can over-ride all the defaults as follows:

    C<<my $ftp = t::ftp_util->new->(
                    user => 'tester',
                    pass => 'secret_word',
                    root => '/path/to/use', # Must be an absolute path.
                    port => 11233,          # Some high integer.
    );

    my $schema = $util->test_schema();>>
    
It's advisable to put any tests based on this in a SKIP block as it requires
a fair few modules and I had some difficulty installing some of them.

E.g.

    C<<SKIP: {

           eval {
                require Test::FTP::Server;
                1;
           }

           or do {
               skip 'Test::TCP and Test::FTP::Server needed for FTP tests'
                   if $EVAL_ERROR;
           };

           use t::ftp_util;
           # Tests go here.
       }>>


=head1 SUBROUTINES/METHODS

=head2 start

Fork the server and return its pid.

head2 stop

Kill the server using the pid returned by start().


=head1 CONFIGURATION AND ENVIRONMENT

=head1 DIAGNOSTICS

Calling tests based on IO::All (specifically the all() method) throws the
following shell errors.

    C<sh: -c: line 0: syntax error near unexpected token `0x8d18100'
      sh: -c: line 0: `Test::FTP::Server::Server=HASH(0x8d18100)'>


=head1 INCOMPATIBILITIES


=head1 BUGS AND LIMITATIONS

I don't know how to mock the host name, so it has to be 'localhost'. We could
use virtual hosts, but this isn't much of a problem.

Test::FTP::Server is convenient for now but is new, may not be well supported
and may remain obscure. It would probably be worth copying functionality from
that module to this and call Net::FTPServer::Full::Server directly.

=head1 AUTHOR

John O'Brien, E<lt>jo3@sanger.ac.ukE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (C) 2010 GRL, by John O'Brien

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

=cut
