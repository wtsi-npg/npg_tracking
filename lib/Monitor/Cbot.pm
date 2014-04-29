#########
# Author:        jo3
# Created:       2010-04-28
#

package Monitor::Cbot;

use Moose;
extends 'Monitor::Instrument';

use Carp;
use LWP::UserAgent;
use namespace::autoclean;

our $VERSION = '0';

use Readonly;
Readonly::Scalar my $DOMAIN          => 'internal.sanger.ac.uk';
Readonly::Scalar my $DEFAULT_TIMEOUT => 10;

has _domain => (
    reader     => 'domain',
    is         => 'ro',
    default    => $DOMAIN,
);

has _host_name => (
    reader     => 'host_name',
    is         => 'ro',
    lazy_build => 1,
);

has _user_agent => (
    reader     => 'user_agent',
    is         => 'ro',
    lazy_build => 1,
);

sub _build__host_name {
    my ($self) = @_;

    my $name = $self->db_entry->name() . q{.} . $self->domain();

    return $name;
}

sub _build__user_agent {
    my ($self) = @_;

    my $ua = LWP::UserAgent->new();

    $ua->env_proxy();
    $ua->agent("Monitor::Cbot v$VERSION jo3\@sanger.ac.uk");
    $ua->requests_redirectable( ['HEAD'] );
    $ua->max_redirect(0);
    $ua->timeout($DEFAULT_TIMEOUT);

    return $ua;
}

# Fetch a response from a url.
sub _fetch {
    my ( $self, $url ) = @_;
    croak 'url required as argument' if !defined $url;

    my $ua       = $self->user_agent();
    my $response = $ua->get($url);

    croak "fetch $url failed: " . $response->status_line()
        if !$response->is_success;

    return $response;
}


sub get_element_content {
    my ( $self, $xml, $tagname ) = @_;

    croak 'No XML supplied' if !defined $xml;
    croak 'First argument is not a XML::LibXML::Document object'
        if ref $xml ne 'XML::LibXML::Document';

    croak 'No tag name supplied' if !defined $tagname;

    my @nodes = $xml->getElementsByTagName($tagname);
    return q{} if scalar @nodes == 0;

    return $nodes[0]->textContent();
}

no Moose;
__PACKAGE__->meta->make_immutable();


1;


__END__


=head1 NAME

Monitor::Cbot - base class for cBot XML interrogation

=head1 VERSION

=head1 SYNOPSIS

    C<<use Monitor::Cbot;

      my $check        = Monitor::Cbot->new_with_options(} );

      my $instr_stat   = $check->get_instrumentstatus();
      my $runlist_stat = $check->get_runlist();
      my $run_status   = $check->get_runinfo('run_label');>>

=head1 DESCRIPTION

Provide the core attributes and methods for the cbot library.    

=head1 SUBROUTINES/METHODS

=head2 get_element_content

Retrieve the content of a particular xml element. Requires an
XML::LibXML::Document object as its first argument and the tagname of the
element as the second. Silently returns an empty string if the tag name is not
found.

=head1 CONFIGURATION AND ENVIRONMENT

The environment variable HTTP_PROXY must be set.

This class is written to support the script cbot_checker. The script should be
called with the argument --ident, and optionally, the argument --dev

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

I don't know how stable the format of the reports are. This code can change at
any time.

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
