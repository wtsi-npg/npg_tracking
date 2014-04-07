#########
# Author:        mg8
# Created:       15 March 2012
#

use strict;
use warnings;
use Test::More tests => 6;

my @imports = qw/sanger_cookie_name sanger_username/;
use_ok('npg::authentication::sanger_sso', @imports);
can_ok('npg::authentication::sanger_sso', @imports);

is(sanger_cookie_name(), 'WTSISignOn', 'sanger cookie name');
is(sanger_username(), q[], 'empty string returned if neither the cookie nor key is given');
is(sanger_username('cookie'), q[], 'empty string returned if the  key is not given');
is(sanger_username(undef, 'mykey'), q[], 'empty string returned if the cookie is not given');

1;