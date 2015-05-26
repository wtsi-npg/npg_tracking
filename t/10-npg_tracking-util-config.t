use strict;
use warnings;
use Test::More tests => 10;

BEGIN {
  local $ENV{'HOME'} = 't';
  use_ok('npg_tracking::util::config');
}

my $package = 'npg_tracking::util::config';

my @methods = qw/ get_config
                  get_config_repository
                  get_config_staging_areas
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
is($config->{'prefix'}, '/nfs/sf', 'prefix retrieved');

1;
