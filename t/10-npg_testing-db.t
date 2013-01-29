BEGIN {
  package db_role_user;
  use Moose;
  with 'npg_testing::db';
  no Moose;
}

package main;
use strict;
use warnings;
use Test::More tests => 1;

isa_ok(db_role_user->new(), 'db_role_user');

1;