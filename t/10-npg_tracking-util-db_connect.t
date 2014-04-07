use strict;
use warnings;
use Test::More tests => 15;
use Test::Deep;
use Test::Exception;
use Cwd;

BEGIN {
  use_ok('npg_tracking::util::db_connect');
}

{
  package t::connection;
  use Moose;

  sub connection {
    my ($self, @info) = @_;
    return @info;
  }
  sub storage {return 0;}
}

{
  package t::magic::connection;
  use Moose;
  extends 't::connection';
  with 'npg_tracking::util::db_connect';
}

{
  my $mc = t::connection->new();
  is (join(q[:], $mc->connection((2, 3))), q[2:3], 'info in and out for a base object');
  is ($mc->connection(), 0, 'undef in and out for a base object');
}

my $dsn      = q[DBI:mysql:database=testname;host=testhost;port=9999];
my $user     = q[testuser];
my $password = q[testpass];

{
  local $ENV{dev}  = q[test];
  local $ENV{HOME} = q[t];
  my $mc = t::magic::connection->new();
  is (join(q[:], $mc->connection((2, 3))), q[2:3], 'info in and out for a magic object');
  cmp_deeply ( [$mc->connection()], [ $dsn, $user, $password, undef ], 'info out with nothing in for a magic object, dev=test, .npg directory in home directory');
}

{
  local $ENV{dev}  = q[test];
  local $ENV{HOME} = q[];
  my $current = getcwd();
  chdir 't';
  my $mc = t::magic::connection->new();
  cmp_deeply ( [$mc->connection()], [ $dsn, $user, $password, undef ], 'info out with nothing in for a magic object, dev=test, .npg dir in the current directory');
  chdir $current;
}

{
  local $ENV{dev}  = q[dev];
  my $mc = t::magic::connection->new(_config_file => 't/.npg/t-magic-connection');
  is (join(q[:], $mc->connection((2, 3))), q[2:3], 'info in and out for a magic object');
  cmp_deeply ( [$mc->connection()], [ 'DBI:mysql:database=devname;host=devhost;port=3321', 'warehouse_ro', '', undef ], 'info out with nothing in for a magic object, dev=dev; config file supplied');
}

{
  my $mc = t::magic::connection->new(_config_file => 't/.npg/t-magic-connection');
  cmp_deeply ( [$mc->connection()], [ 'DBI:mysql:database=name;host=host;port=3306', 'warehouse_ro', '', undef ], 'info out with nothing in for a magic object, dev not set; config file supplied');
}

{
  local $ENV{dev}  = q[unknown];
  my $mc = t::magic::connection->new(_config_file => 't/.npg/t-magic-connection');
  throws_ok {$mc->connection()} qr/No database defined in t\/\.npg\/t-magic-connection/,
    'error when non-existing domain is set';
}

{
  local $ENV{dev} = q[test];
  my $mc = t::magic::connection->new(_config_file => 't/.npg/t-magic-connection');
  my @expected = ({dsn=>$dsn, user=>$user, password=>$password, dodo=>1,});
  cmp_deeply ($mc->connection(({dsn => q[], dodo=>1,})), @expected, 'magic object: info out with array with a no-dsn hash in, dev=test');
}

{
  local $ENV{dev} = q[test];
  my $mc = t::magic::connection->new();
  my @expected = ({dsn=>q[dada], dodo=>1,});
  cmp_deeply ($mc->connection(({dsn => q[dada], dodo=>1,})), @expected, 'magic object: info out with array with a hash in, dev=test');
}

{
  package t::magic::connection2;
  use Moose;
  extends 't::magic::connection';
}

{
  local $ENV{dev} = q[test];
  local $ENV{HOME} = q[t];
  my $mc = t::magic::connection2->new();
  cmp_deeply ( [$mc->connection()], ['dbi:mysql:host=mcs12;database=sequencescape_warehouse;port=3379','warehouse_ro', q(), {mysql_enable_utf8=>1}] , 'magic object: nothing in, dsn and attr out');
}

{
  package t::magic::connection3;
  use Moose;
  extends 't::magic::connection';
}

{
  local $ENV{HOME} = q[t];
  my $mc = t::magic::connection3->new();
  cmp_deeply ( [$mc->connection()], ['dbi:mysql:host=mcs12;database=sequencescape_warehouse;port=3379','warehouse_ro', q(), {mysql_enable_utf8=>1}] , 'magic object: nothing in, dsn and attr out, config file without domains');
}

{
  my $mc = t::magic::connection3->new();
  throws_ok {$mc->connection()} qr/Attribute \(_config_file\) does not pass the type constraint because: Validation failed for 'NpgTrackingReadableFile' (failed )?with value .*\.npg\/t-magic-connection3/, 'error if the config file is not found';
}

1;
