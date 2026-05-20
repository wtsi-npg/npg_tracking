use strict;
use warnings;

use Test::More;

use_ok('npg::authentication::sanger_oidc');

# -----------------------
# Test data
# -----------------------

local %ENV = (
  OIDC_CLAIM_name               => 'Tiger Cat',
  OIDC_CLAIM_preferred_username => 'tiger',
);

my $oidc = npg::authentication::sanger_oidc->new();

# -----------------------
# Constructor
# -----------------------

isa_ok($oidc, 'npg::authentication::sanger_oidc');

# -----------------------
# Accessors
# -----------------------

is($oidc->name,     'Tiger Cat', 'name accessor works');
is($oidc->username, 'tiger', 'username accessor works');

# -----------------------
# Edge cases: missing env
# -----------------------

local %ENV = ();

my $empty = npg::authentication::sanger_oidc->new();

ok(!defined $empty->name,   'missing name returns undef');
ok(!defined $empty->username,'missing username returns undef');

# -----------------------
# Edge case: malformed env (object still works safely)
# -----------------------

my $bad = npg::authentication::sanger_oidc->new();

ok(defined $bad, 'object created even with empty env');

done_testing();
