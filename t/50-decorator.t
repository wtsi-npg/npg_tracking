#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2002009-04-15
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 50-decorator.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/50-decorator.t $
#
use strict;
use warnings;
use Test::More tests => 5;

use_ok(q{npg::decorator});

my $decorator = npg::decorator->new();
isa_ok($decorator, q{npg::decorator}, q{$decorator});
is($decorator->username(), q{}, q{empty string returned when no username provided or cached});
is($decorator->username('test_user'), q{test_user}, q{test_user passed in to username and returned});
is($decorator->username(), q{test_user}, q{test_user returned from cache});