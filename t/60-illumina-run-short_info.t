use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use Moose::Meta::Class;

use t::dbic_util;

use_ok(q{npg_tracking::illumina::run::short_info});

my $schema = t::dbic_util->new->test_schema(
  fixture_path => q[t/data/dbic_fixtures]);

my $rfname = q[20231017_LH00210_0012_B22FCNFLT3];

# Start of package test::short_info
package test::short_info;
use Moose;
with qw{npg_tracking::illumina::run::short_info};

sub _build_run_folder { return $rfname; }
# End of package test::short_info

# Start of package test::db_short_info
package test::db_short_info;
use Moose;
use npg_tracking::Schema;
with qw{npg_tracking::illumina::run::short_info};

has q{npg_tracking_schema} => (
  isa => 'npg_tracking::Schema',
  is => 'ro',
  default => sub { return $schema },
);
# End of package test::db_short_info

# Start of package test::nvx_short_info
package test::nvx_short_info;
use Moose;
with 'npg_tracking::illumina::run::short_info';

has experiment_name => (is => 'rw');
# End of package test::nvx_short_info

package main;

subtest 'object derived directly from the role' => sub {
  plan tests => 6;

  my $class = Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_tracking::illumina::run::short_info/]
  );

  throws_ok { $class->new_object(id_run => 1234)->run_folder() }
    qr{does not support builder method '_build_run_folder'},
    q{Error thrown as no _build_run_folder method in class};

  throws_ok { $class->new_object(run_folder => q[export/sv03/my_folder]) }
    qr{Attribute \(run_folder\) does not pass the type constraint},
    'error supplying a directory path as the run_folder attribute value';

  throws_ok { $class->new_object(run_folder => q[]) }
    qr{Attribute \(run_folder\) does not pass the type constraint},
    'error supplying an empty atring as the run_folder attribute value';

  my $obj = $class->new_object(run_folder => q[my_folder], id_run => 1234);
  is ($obj->run_folder, 'my_folder', 'the run_folder value is as set');
  is ($obj->id_run, 1234, 'id_run value is as set');

  throws_ok { $class->new_object(run_folder => q[my_folder])->id_run }
    qr{Unable to identify id_run with data provided},
    'error building id_run';
};

subtest 'object with a bulder method for run_folder' => sub {
  plan tests => 1;

  is (test::short_info->new(id_run => 47995)->run_folder, $rfname,
    'value of run_folder attribute is set by the builder method');
}; 

subtest 'object with access to tracking database' => sub {
  plan tests => 2;

  throws_ok { test::db_short_info->new(run_folder => 'xxxxxx')->id_run }
    qr{Unable to identify id_run with data provided},
    'error building id_run when no db record for the run folder exists';
  is (test::db_short_info->new(run_folder => $rfname)->id_run, 47995,
    'id_run value retrieved from the database recprd');
};

subtest 'Test id_run extraction from within experiment_name' => sub {
  plan tests => 7;
  my $short_info = test::nvx_short_info->new(experiment_name => '45678_NVX1_A', run_folder => 'not_a_folder');
  is($short_info->id_run, '45678', 'id_run parsed from experiment name');

  $short_info = test::nvx_short_info->new(experiment_name => '  45678_NVX1_A   ', run_folder => 'not_a_folder');
  is($short_info->id_run, '45678', 'id_run parsed from loosely formatted experiment name');

  $short_info = test::nvx_short_info->new(experiment_name => '45678_NVX1_A   ', run_folder => 'not_a_folder');
  is($short_info->id_run, '45678', 'id_run parsed from experiment name with postfix spaces');

  $short_info = test::nvx_short_info->new(experiment_name => '  45678_NVX1_A', run_folder => 'not_a_folder');
  is($short_info->id_run, '45678', 'id_run parsed from experiment name with prefixed spaces');

  $short_info = test::nvx_short_info->new(experiment_name => '45678', run_folder => 'not_a_folder');
  is($short_info->id_run, '45678', 'Bare id_run as experiment name is fine');

  $short_info = test::nvx_short_info->new(experiment_name => 'NovaSeqX_WHGS_TruSeqPF_NA12878', run_folder => 'not_a_folder');
  throws_ok { $short_info->id_run } qr{Unable to identify id_run with data provided}, 'Custom run name cannot be parsed';

  $short_info = test::nvx_short_info->new(id_run => '45678', experiment_name => '56789_NVX1_A', run_folder => 'not_a_folder');
  is($short_info->id_run, '45678', 'Set id_run wins over experiment_name');
};

1;
