use strict;
use warnings;

BEGIN {
	$ENV{NPG_DATA_ROOT}='../data';
}

use Test::More tests => 4;
use Test::Exception;
use t::util;
use DateTime;
use npg::oidc;

my $oidc = npg::oidc->new;
is($oidc->domain, 'oidc_google');
is($oidc->client_id(), '228360129981.apps.googleusercontent.com');
is($oidc->server, 'https://accounts.google.com');
is($oidc->access_token_path, '/o/oauth2/token');

1;
