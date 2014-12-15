use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use Moose::Meta::Class;

use_ok('st::api::lims::ml_warehouse');

my $schema_wh;
lives_ok {Moose::Meta::Class->create_anon_class(
  roles => [qw/npg_testing::db/])->new_object({})->create_test_db(
  q[WTSI::DNAP::Warehouse::Schema],q[t/data/fixtures_stlims_wh]) 
} 'ml_warehouse test db created';



1;