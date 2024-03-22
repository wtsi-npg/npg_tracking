use strict;
use warnings;
use Test::More tests => 13;

BEGIN {
  local $ENV{'HOME'} = 't';
  use_ok('npg_tracking::util::config');
}

my $package = 'npg_tracking::util::config';

my @methods = qw/ get_config
                  get_config_repository
                  get_config_staging_areas
                  get_config_users
                /;
can_ok($package, @methods);

my $config = $package->get_config;
isa_ok ($config, 'HASH');
ok(exists $config->{'staging_areas'}, 'staging area entry exists');
ok(exists $config->{'repository'}, 'repository entry exists');
ok(exists $config->{'mock'}, 'mock entry exists');

$config = $package->get_config_repository;
isa_ok ($config, 'HASH');
is($config->{'root'}, '/lustre/scratch109/srpipe/', 'ref rep root retrieved');

$config = npg_tracking::util::config::get_config_staging_areas;
isa_ok ($config, 'HASH');
is($config->{'prefix'}, '/tmp/esa-sv-*', 'prefix retrieved');

$config = npg_tracking::util::config::get_config_users;
isa_ok ($config, 'HASH');
my $users = $config->{'production'};
isa_ok ($users, 'ARRAY');
is(join(q[ ], @{$users}), 'userone usertwo', 'users retrieved');

1;
