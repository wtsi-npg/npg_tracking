# Author:        js10@sanger.ac.uk
# Created:       2013-12-16
#
# Helper methods for handling Open ID Connect authentication
#
package npg::oidc;

use strict;
use warnings;

use English '-no_match_vars';
use Moose;
use MIME::Base64::URLSafe;
use Crypt::OpenSSL::X509;
use Crypt::OpenSSL::RSA;
use Date::Parse;
use LWP::UserAgent;
use HTTP::Response;
use JSON;
use CGI;
use Carp;
use Config::Auto;
use Net::SSL 2.85;
use Net::SSLeay 1.55;
use Crypt::SSLeay 0.57;

use Readonly;

$Net::HTTPS::SSL_SOCKET_CLASS = 'Net::SSL'; # Force use of Net::SSL

Readonly::Scalar our $CONFIG_FILE  => $ENV{NPG_DATA_ROOT}.'/config.ini';

has domain => (
	is            => 'ro',
    isa            => 'Str',
    default        => 'oidc_google',
);

has config => (
    is            => 'ro',
    isa            => 'HashRef',
    lazy_build    => 1,
);

sub _build_config {
    return Config::Auto::parse($CONFIG_FILE);
}

has certs => (
	is			=> 'rw',
	isa			=> 'HashRef',
);

has client_id => (
    is            => 'ro',
    isa            => 'Str',
    lazy_build    => 1,
);

sub _build_client_id {
    my $self = shift;
    return $self->config->{$self->domain}->{client_id};
}

has client_secret => (
    is            => 'ro',
    isa            => 'Str',
    lazy_build    => 1,
);

sub _build_client_secret {
    my $self = shift;
    return $self->config->{$self->domain}->{client_secret};
}

has server => (
    is            => 'ro',
    isa            => 'Str',
    lazy_build    => 1,
);

sub _build_server {
    my $self = shift;
    return $self->config->{$self->domain}->{server};
}

has access_token_path => (
    is            => 'ro',
    isa            => 'Str',
    lazy_build    => 1,
);

sub _build_access_token_path {
    my $self = shift;
    return $self->config->{$self->domain}->{access_token_path};
}

has authorize_path => (
    is            => 'ro',
    isa            => 'Str',
    lazy_build    => 1,
);

sub _build_authorize_path {
    my $self = shift;
    return $self->config->{$self->domain}->{authorize_path};
}

has logout_path => (
    is            => 'ro',
    isa            => 'Str',
    lazy_build    => 1,
);

sub _build_logout_path {
    my $self = shift;
    return $self->config->{$self->domain}->{logout_path};
}

has certs_url => (
    is            => 'ro',
    isa            => 'Str',
    lazy_build    => 1,
);

sub _build_certs_url {
    my $self = shift;
    return $self->config->{$self->domain}->{certs_url};
}

has https_proxy => (
    is            => 'ro',
    isa            => 'Maybe[Str]',
    lazy_build => 1,
);

sub _build_https_proxy {
    my $self = shift;
    return $self->config->{$self->domain}->{https_proxy};
}

has certs_cache_file => (
    is            => 'ro',
    isa            => 'Str',
    default        => '/tmp/certs.txt',
);

has short_cookie_name => (
    is            => 'ro',
    isa            => 'Str',
    default        => 'OIDC_SHORT_COOKIE',
);

has long_cookie_name => (
    is            => 'ro',
    isa            => 'Str',
    default        => 'OIDC_LONG_COOKIE',
);

sub getidtoken
{
    my $self = shift;
    my $code = shift;
    my $redirect_uri = shift;

    croak 'No code specified to getidtoken' if !$code;
    croak 'No redirect_uri specified to getidtoken' if !$redirect_uri;

    my %fields = ('code' => $code,
                  'client_id' => $self->client_id,
                  'client_secret' => $self->client_secret,
                  'redirect_uri' => $redirect_uri,
                  'grant_type' => 'authorization_code',);
    my $ua = LWP::UserAgent->new();
    $ua->ssl_opts(verify_hostname => 0, SSL_Debug => 0);
    local $ENV{'https_proxy'} = $self->https_proxy;
    my $response = HTTP::Response->new();
    $response = $ua->post($self->server.$self->access_token_path, \%fields);
    if (!$response->is_success) {
        warn 'Authorization Failed: ', $response->status_line, "\n";
        croak $response->content;
    }
    # let's try decoding the response
    my $j = decode_json($response->content());
    return $j->{id_token};
}


#
# Check that the signature on the token is valid.
# Validation Code based on GoogleIDToken::Validator by Dmitry Mukhin
# See http://search.cpan.org/~dimanoid/GoogleIDToken-Validator-0.02/
#
sub verify
{
    my ($self, $token) = @_;
    if ($self->certs_expired()) { $self->get_certs; };

    my ($env, $payload, $signature) = split /\./smx, $token;
    my $signed = "$env.$payload";

    $signature = urlsafe_b64decode($signature);
    $env = decode_json(urlsafe_b64decode($env));
    $payload = decode_json(urlsafe_b64decode($payload));

    if (!exists $self->certs->{$env->{kid}}) {
        carp "There are no such certificate that used to sign this token (kid: $env->{kid}).";
        return;
    }
    my $rsa = Crypt::OpenSSL::RSA->new_public_key($self->certs->{$env->{kid}}->pubkey());
    $rsa->use_sha256_hash();

    if (!$rsa->verify($signed, $signature)) {
        carp 'Signature is wrong.';
        return;
    }

    if ($payload->{aud} ne $self->client_id) {
        carp "Web Client ID missmatch. ($payload->{aud}).";
        return;
    }

    return $payload;
}

sub certs_expired
{
    my $self = shift;
    return 1 if (!$self->certs);
    foreach my $kid (keys %{$self->certs}) {
        return 1 if (str2time($self->certs->{$kid}->notAfter()) < time);
    }
    return 0;
}

sub get_certs
{
    my $self = shift;
    if ($self->certs_cache_file && -e $self->certs_cache_file) {
        $self->get_certs_from_file();
    }
    if ($self->certs_expired()) {
        $self->get_certs_from_web();
    }
	return;
}

sub get_certs_from_web
{
    my $self = shift;
    my $ua = LWP::UserAgent->new();
    local $ENV{'https_proxy'} = $self->https_proxy;
    $ua->ssl_opts(verify_hostname => 0);
    $ua->proxy(['https'], undef);
    my $response = HTTP::Response->new();
    $response = $ua->get($self->certs_url);
    if ($response->is_success) {
        my $json_certs = $response->content;
        if ($json_certs) {
            $self->parse_certs($json_certs);
            open my $fh, '>',$self->certs_cache_file or croak "Can't write certs to cache file($self->certs_cache_file): ".$ERRNO;
            my $return_value = print ${fh} $json_certs;
            $return_value = close $fh;
        }
    } else {
        croak "ERROR getting certs from $self->certs_url";
    }
	return;
}

sub get_certs_from_file
{
    my $self = shift;
    open my $fh, '<', $self->certs_cache_file or croak "Can't read certs from cache file($self->certs_cache_file): ".$ERRNO;
    my $json_certs = q();
    while(<$fh>) { $json_certs .= $_ }
    if ($json_certs) {
        $self->parse_certs($json_certs);
    } else {
        $self->certs = undef;
    }
    close $fh || croak "Failed to close certificate file $self->certs_cache_file";
	return;
}

sub parse_certs
{
    my ($self, $json_certs) = @_;
    my $certs = decode_json($json_certs);
	$self->certs({});
    foreach my $kid (keys %{$certs}) {
        $self->certs->{$kid} = Crypt::OpenSSL::X509->new_from_string($certs->{$kid});
    }
	return;
}


1;


__END__

=head1 NAME

  npg::oidc

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

Module to handle the Open ID Connect protocol

=head1 SUBROUTINES/METHODS

=head2 certs_expired

=head2 getidtoken - ask the OIDC server for an ID Token

    my $idToken = $oidc->getidtoken($code, $redirect_uri);

=head2 get_certs

=head2 get_certs_from_file

=head2 get_certs_from_web

=head2 parse_certs

=head2 verify - verify that a received signature is correct. Returns payload or undef

    my $payload = $oidc->verify($token);
    die "Invalid signature" if !$payload;

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose;

=item MIME::Base64::URLSafe;

=item Crypt::OpenSSL::X509;

=item Crypt::OpenSSL::RSA;

=item Date::Parse;

=item LWP::UserAgent;

=item HTTP::Response;

=item JSON;

=item CGI;

=item Carp;

=item Config::Auto;

=item Net::SSL 2.85;

=item Net::SSLeay 1.55;

=item Crypt::SSLeay 0.57;

=item Readonly; 

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Jennifer Liddle <js10@sanger.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013 GRL, by Jennifer Liddle (js10@sanger.ac.uk)

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
