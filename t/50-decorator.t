use strict;
use warnings;
use Test::More tests => 5;

use_ok(q{npg::decorator});

my $decorator = npg::decorator->new();
isa_ok($decorator, q{npg::decorator}, q{$decorator});
is($decorator->username(), q{}, q{empty string returned when no username provided or cached});
is($decorator->username('test_user'), q{test_user}, q{test_user passed in to username and returned});
is($decorator->username(), q{test_user}, q{test_user returned from cache});