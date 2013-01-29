#########
# Author:        mg8
# Maintainer:    $Author: js10 $
# Created:       15 March 2012
# Last Modified: $Date: 2012-03-20 12:02:08 +0000 (Tue, 20 Mar 2012) $
# Id:            $Id: 10-authentication-sanger_sso.t 15357 2012-03-20 12:02:08Z js10 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-authentication-sanger_sso.t $
#

use strict;
use warnings;

use Test::More tests => 6;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 15357 $ =~ /(\d+)/mx; $r; };

my @imports = qw/sanger_cookie_name sanger_username/;
use_ok('npg::authentication::sanger_sso', @imports);
can_ok('npg::authentication::sanger_sso', @imports);

is(sanger_cookie_name(), 'WTSISignOn', 'sanger cookie name');
is(sanger_username(), q[], 'empty string returned if neither the cookie nor key is given');
is(sanger_username('cookie'), q[], 'empty string returned if the  key is not given');
is(sanger_username(undef, 'mykey'), q[], 'empty string returned if the cookie is not given');

1;