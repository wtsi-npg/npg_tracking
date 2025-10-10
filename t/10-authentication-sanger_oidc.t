use strict;
use warnings;

use Test::More;

use_ok('npg::authentication::sanger_oidc');

# -----------------------
# Test data
# -----------------------

local %ENV = (
    OIDC_CLAIM_sub                => 'user-123',
    OIDC_CLAIM_email              => 'tiger@example.com',
    OIDC_CLAIM_name               => 'Tiger Cat',
    OIDC_CLAIM_preferred_username => 'tiger',
    OIDC_CLAIM_groups             => 'admin,users,dev',
    OIDC_access_token             => 'access-token-abc',
    OIDC_id_token                 => 'id-token-xyz',
);

my $oidc = npg::authentication::sanger_oidc->new();

# -----------------------
# Constructor
# -----------------------

isa_ok($oidc, 'npg::authentication::sanger_oidc');

# -----------------------
# Accessors
# -----------------------

is($oidc->subject,  'user-123',        'subject accessor works');
is($oidc->email,    'tiger@example.com','email accessor works');
is($oidc->name,     'Tiger Cat',     'name accessor works');
is($oidc->username, 'tiger',           'username accessor works');

is($oidc->access_token, 'access-token-abc', 'access token works');
is($oidc->id_token,     'id-token-xyz',     'id token works');

# -----------------------
# Groups parsing
# -----------------------

is(
    $oidc->groups,
    'admin,users,dev',
    'groups accessor returns raw string'
);

# -----------------------
# has_group
# -----------------------

ok($oidc->has_group('admin'),   'has_group detects admin');
ok($oidc->has_group('users'),   'has_group detects users');
ok(!$oidc->has_group('missing'),'has_group rejects unknown group');

# -----------------------
# Edge cases: missing env
# -----------------------

local %ENV = ();

my $empty = npg::authentication::sanger_oidc->new();

ok(!defined $empty->subject, 'missing sub returns undef');
ok(!defined $empty->email,   'missing email returns undef');
ok(!defined $empty->username,'missing username returns undef');

is($empty->groups, undef, 'missing groups returns undef');

ok(!$empty->has_group('admin'), 'has_group false when no groups');

# -----------------------
# Edge case: malformed env (object still works safely)
# -----------------------

my $bad = npg::authentication::sanger_oidc->new();

ok(defined $bad, 'object created even with empty env');

# -----------------------
# Edge case: whitespace groups
# -----------------------

local %ENV = (
    OIDC_CLAIM_groups => 'admin, users , dev',
);

my $ws = npg::authentication::sanger_oidc->new();

ok($ws->has_group('admin'), 'handles admin group');
ok(!$ws->has_group(' users '), 'whitespace trimmed correctly');

done_testing();
