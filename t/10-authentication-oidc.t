use strict;
use warnings;

BEGIN {
	$ENV{NPG_DATA_ROOT}='../data';
}

use Test::More tests => 4;
use Test::Exception;
use t::util;
use DateTime;
use npg::authentication::oidc;

my $oidc = npg::authentication::oidc->new;
is($oidc->domain, 'oidc_google');
is($oidc->client_id(), '127851258812.apps.googleusercontent.com');
is($oidc->server, 'https://accounts.google.com');
is($oidc->access_token_path, '/o/oauth2/token');

1;
