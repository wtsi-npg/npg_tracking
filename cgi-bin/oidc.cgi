#!/usr/bin/perl -T

use strict;
use warnings;
use diagnostics;

our @npg_libs;

BEGIN {
  my $libs_string = $ENV{'NPG_PERL5LIB'};
  if ($libs_string) {
    my @libs = split /:/smx, $libs_string;
    foreach my $l (@libs) {
      my ($dtl) = $l =~ /([a-z0-9\/\._\-]+)/i;
      if ($dtl) {push @npg_libs, $dtl;}
    }
  }

}

use lib @npg_libs;

use Carp 'verbose';
use CGI qw(cookie -debug);
use CGI::Carp;
use CGI::Cookie;
use HTTP::Request;
use HTTP::Response;
use URI::Escape;
use JSON;
use MIME::Base64 qw(decode_base64url encode_base64 decode_base64);
use npg::oidc;


=head
{
no strict 'refs';
warn "=== MODULES ===\n";
foreach my $k( keys %INC){ my $x=$k;$x=~s/.pm//;$x=~s#/#::#g;my $v=${$x."::VERSION"};warn "$k ($v): $INC{$k}\n";}
warn "=== ENVIRONMENT ===\n";
foreach my $k (keys %ENV) { warn "$k = $ENV{$k}\n"; }
}
=cut


our $VERSION = '0.0.1';

our $oidc = npg::oidc->new;
our $q = CGI->new;
our $COOKIE_EXPIRED = cookie(-name => 'WTSISignOn', -value => q(), -expires => '-1d', -domain => '.sanger.ac.uk', -httponly => 1, -secure => 0 );

my $authtype = $q->param('authtype') || '';
my $destination = $q->param("destination") || '';
my $code = $q->param('code') || '';

$destination ||= $ENV{HTTP_REFERER};
if ($destination) { ($destination) = $destination=~/\A(.+)\z/smx; } #TO CHECK: do I ned to be more careful here?

if ($authtype eq 'google') {
	googleLogin($destination);
	exit 0;
}

# we have been redirected here from the Open ID Connect server
if ($code) {
	# first validate the state
	my %cookies = CGI::Cookie->fetch();
	if ($q->param('state') ne $cookies{'OIDC_STATE'}->value()) {
		die "Meep! State is wrong!\n  Was: ", $cookies{'OIDC_STATE'}->value(), "\n   Is: ", $q->param('state'), "\n";
	}
	# send the code back to the server to get an id_token
	my $id_token = $oidc->getidtoken($code, 'https://'.$ENV{SERVER_NAME}.$ENV{SCRIPT_NAME});
	my @a = split '\.', $id_token;
	my $profile = decode_base64url($a[1]);
	my $p = decode_json($profile);
	die "Email not verified" unless ($p->{email_verified} eq 'true');
	my $destination = $cookies{'DEST'}->value();
	my $shortCookie = createShortCookie($id_token);
	my $longCookie = createLongCookie($id_token);
	my $payload = $oidc->verify($id_token);	# lets try validating it by checking the signature
	die "Invalid token!" if (!$payload);
	# everything is cool. Redirect to where we wanted to go in the first place
	redirect($destination, [$shortCookie, $longCookie]);
}

#
# This is the logout code
#
my $shortCookie = createShortCookie('','-1d');
my $longCookie = createLongCookie('','-1d');
my $url;
my $cval = $q->cookie(-name => $oidc->short_cookie_name);
# if we are logged in via google, then logout via google
if ($cval) {
	$url = $oidc->server . $oidc->logout_path . "?continue=$destination";
} else {
	$url = $destination;
}

# logout and redirect
redirect($url,[$COOKIE_EXPIRED,$shortCookie, $longCookie]);



sub googleLogin
{
	# the first thing to do is save the final destination. We'll need it later...
	my $destination = shift;
	my $destCookie = $q->cookie('DEST' => $destination);

	# create and save a state for checking later
	my $state = 'sanger.ac.uk.' . rand();
	my $cookie = $q->cookie('OIDC_STATE' => $state);
	# build a URL to the authorization server
	my $url = $oidc->server.$oidc->authorize_path;
	$url .= '?client_id='.uri_escape($oidc->client_id);
	$url .= '&scope='.uri_escape('openid email');
	$url .= '&response_type='.uri_escape('code');
	$url .= '&state='.uri_escape($state);
	$url .= '&redirect_uri=https://'.$ENV{SERVER_NAME}.$ENV{SCRIPT_NAME};
	# redirect to authorization server
	redirect($url, [$cookie, $destCookie]);
}

sub createShortCookie
{
	my $cookie_value = shift;
	my $expire = shift;
	$expire ||= '+10h';
	my $cookie = $q->cookie(-name => $oidc->short_cookie_name,
	                        -value => $cookie_value,
	                        -expires => $expire,
	                        -domain => '.sanger.ac.uk',
	                        -secure => 0,
	                        -httponly => 1);
	return $cookie;
}

sub createLongCookie
{
	my $cookie_value = shift;
	my $expire = shift;
	$expire ||= '+10h';
	my $cookie = $q->cookie(-name => $oidc->long_cookie_name,
	                        -value => $cookie_value,
	                        -expires => $expire,
	                        -domain => $ENV{HTTP_HOST},
	                        -secure => 0,
	                        -httponly => 1);
	return $cookie;
}

sub redirect
{
	my $destination = shift;
	my $cookies = shift;
	print $q->redirect(-uri => $destination, -cookie => $cookies);
	exit 0;
}

