use strict;
use warnings;

use Test::More;

use_ok('npg::authentication::sanger_oidc');

# Constructor

{
  local %ENV = (
    OIDC_CLAIM_name               => 'Tiger Cat',
    OIDC_CLAIM_preferred_username => 'tiger',
  );
  my $oidc = npg::authentication::sanger_oidc->new();
  isa_ok($oidc, 'npg::authentication::sanger_oidc', 'object created');
}

# name accessor

{
  local %ENV = (OIDC_CLAIM_name => 'Tiger Cat');
  is(npg::authentication::sanger_oidc->new()->name, 'Tiger Cat', 'name returns display name');
}

# username: plain username, no domain

{
  local %ENV = (OIDC_CLAIM_preferred_username => 'tiger');
  is(npg::authentication::sanger_oidc->new()->username, 'tiger', 'username returns plain username');
}

# username: strips domain from email-format preferred_username

{
  local %ENV = (OIDC_CLAIM_preferred_username => 'tiger@email.ac.uk');
  is(npg::authentication::sanger_oidc->new()->username, 'tiger',
    'username strips domain from email-format preferred_username');
}

# username: only the local part before the first @

{
  local %ENV = (OIDC_CLAIM_preferred_username => 'tiger@foo@bar');
  is(npg::authentication::sanger_oidc->new()->username, 'tiger',
    'username takes only the part before the first @');
}

# username: improper value starting with @ (missing local part)

{
  local %ENV = (OIDC_CLAIM_preferred_username => '@email.ac.uk');
  is(npg::authentication::sanger_oidc->new()->username, q{},
    'username starting with @ returns empty string (no local part)');
}

# Independent env vars: name unaffected by missing username and vice versa

{
  local %ENV = (OIDC_CLAIM_name => 'Tiger Cat');
  my $auth = npg::authentication::sanger_oidc->new();
  is($auth->name, 'Tiger Cat', 'name works when username env is absent');
  ok(!defined $auth->username,  'username undef when only name env is set');
}

# Missing env vars

{
  local %ENV = ();
  my $empty = npg::authentication::sanger_oidc->new();
  ok(!defined $empty->name,     'missing OIDC_CLAIM_name returns undef');
  ok(!defined $empty->username, 'missing OIDC_CLAIM_preferred_username returns undef');
}

# Empty string env var treated as missing

{
  local %ENV = (OIDC_CLAIM_preferred_username => q{});
  ok(!defined npg::authentication::sanger_oidc->new()->username,
    'empty preferred_username returns undef');
}

done_testing();
