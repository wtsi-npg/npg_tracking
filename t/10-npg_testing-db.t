BEGIN {
  package db_role_user;
  use Moose;
  with 'npg_testing::db';
  no Moose;
}

package main;
use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;

my $db_role_user = db_role_user->new();
isa_ok($db_role_user, 'db_role_user');

throws_ok {$db_role_user->deploy_test_db()}
  qr/dev environment variable should be set to \"test\"/,
  'error if not test environment';

local $ENV{'dev'} = 'test';

throws_ok {$db_role_user->deploy_test_db()} qr/Configuration file path is not set/,
  'configuration file path should be set';
$db_role_user = db_role_user->new(config_file => 't/.npg/t-magic-connection');
throws_ok {$db_role_user->deploy_test_db()} qr/Schema package undefined/,
  'schema package should be given';
throws_ok {$db_role_user->deploy_test_db('npg_tracking::does::not::exist')}
  qr/Can't locate npg_tracking\/does\/not\/exist.pm/,
  'should be possible to load the schema package into memory';

1;