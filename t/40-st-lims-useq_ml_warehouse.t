use strict;
use warnings;
use Test::More tests => 10;
use Test::Exception;

#####
# The tests below demonstrate the behaviour of st::api::lims class with
# the useq_ml_warehouse driver type.

use_ok('st::api::lims');

my $id_run = 51815;
my $control_tag_index = 9999;

my $schema_wh;
lives_ok { $schema_wh = Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/])->new_object({})->create_test_db(
    q[WTSI::DNAP::Warehouse::Schema],q[t/data/fixtures_lims_wh_samplesheet]) 
} 'ml_warehouse test db created';

subtest 'pure db driver, no product table entries' => sub {
  plan tests => 3;

  my $init = {
    id_run => 2,
    driver_type => 'useq_ml_warehouse',
    mlwh_schema => $schema_wh
  };

  lives_ok { st::api::lims->new($init) } 'object creation is OK';
  throws_ok { st::api::lims->new($init)->children() }
    qr/No product records for run 2/,
    'error calling a method that requires db data present';

  $init->{id_run} = $id_run;
  $init->{position} = 1;
  $init->{tag_index} = 300;
  throws_ok { st::api::lims->new($init)->qc_state }
    qr/No useq_product_metrics database record retrieved/,
    'error calling a method that requires db data present';
};

subtest 'combo driver, no product or LIMS table entries' => sub{
  plan tests => 7;

  my $l;
  lives_ok { $l = st::api::lims->new(
    id_run => 2,
    runfolder_path => 't/data/ultimagen/425347-20250821_1214',
    driver_type => 'useq_ml_warehouse',
    mlwh_schema => $schema_wh
  ) } 'object creation is OK';
  my @children;
  lives_ok { @children = $l->children() }
    'can create children';
  is (scalar(@children), 8, 'correct number of children');
  my $child = $children[3];
  is ($child->id_run, 2, 'id_run is assigned correctly');
  is ($child->tag_index, 4, 'tag index is assigned correctly');
  my $error = 'No useq_wafer database record retrieved for ' .
    'wafer ID "18Aug25 D7_CooperSteer_5priem plus guide" and ' .
    'st::api::lims::useq_ml_warehouse id_run 2, tag_index 4';
  throws_ok { $child->tag_sequence() }
    qr/$error/, 'error accessing tag_sequence property';
  throws_ok { $child->study_name() }
    qr/$error/, 'error accessing study_name property';
};

subtest 'family tree, product table entries are present' => sub {
  plan tests => 85;

  my $l = st::api::lims->new(
    id_run      => $id_run,
    driver_type => 'useq_ml_warehouse',
    mlwh_schema => $schema_wh
  );
  ok ($l->is_pool, 'run is a pool');
  ok (!$l->is_control, 'run is not a sequencing control');
  is ($l->tag_index, undef, 'tag index is not defined for a run');
  is ($l->spiked_phix_tag_index, $control_tag_index,
    'control tag index is defined for a run and is correct');
  
  my @products = $l->children();
  is (scalar @products, 7, 'seven products');
  is ($l->num_children, 7, 'seven children');
  my @indices = ();
  for my $p (@products) {
    is ($p->driver_type, 'useq_ml_warehouse', 'driver type is correct');
    is ($p->driver->mlwh_schema, $schema_wh, 'original db connection is used');
    ok (!$p->is_pool, 'not a pool');
    is ($p->position, undef, "position is undefined");
    is ($p->id_run, $id_run, 'id_run is propagated');
    is (scalar $p->children(), 0, 'no children');
    is ($p->num_children, 0, 'no children');
    ok ($p->tag_index, 'tag index is defined and is not zero');
    ok (!$p->is_control, 'product is not sequencing control');
    is ($p->spiked_phix_tag_index, $control_tag_index,
      'control tag index is correct');
    push @indices, $p->tag_index;
  }
  is (join(q[ ], @indices), '97 98 99 100 101 102 103',
    'correct sorted tag indices');

  my $init = {
    id_run      => $id_run,
    position    => 1,
    driver_type => 'useq_ml_warehouse',
    mlwh_schema => $schema_wh
  };
  $l = st::api::lims->new($init);
  for my $p ($l->children()) {
    is ($p->position, 1, "position is propagated as 1");
  }
 
  $init->{position} = 2;
  throws_ok { st::api::lims->new($init)->children() }
    qr/Cannot assign 2 to position/,
    'error assigning 2 to the position attribute';
};

subtest 'LIMS properties for a product' => sub { 
  plan tests => 20;

  my $l = st::api::lims->new(
    id_run      => $id_run,
    tag_index   => 100,
    driver_type => 'useq_ml_warehouse',
    mlwh_schema => $schema_wh
  );
  ok (!$l->is_pool, 'product is not a pool');
  ok (!$l->is_control, 'product is not a control');
  is ($l->sample_id, '4396728', 'sample id');
  is ($l->sample_name, '6133STDY8786709', 'sample name');
  is ($l->study_id, '2239', 'study id');
  is ($l->study_name, 'MPN Whole Genomes', 'study name');
  is ($l->default_tag_sequence, 'CGGATCATGCGTGAT', 'barcode');
  is ($l->default_tagtwo_sequence, undef, 'no second barcode');
  is ($l->library_type, 'Ultima High Throughput PCR Free 96', 'library type');
  is ($l->lane_id, '76975170', 'lane id');

  # No LIMS data for Ultimagen control
  $l = st::api::lims->new(
    id_run      => $id_run,
    tag_index   => $control_tag_index,
    driver_type => 'useq_ml_warehouse',
    mlwh_schema => $schema_wh
  );
  ok (!$l->is_pool, 'product is not a pool');
  ok ($l->is_control, 'product is a control');
  is ($l->sample_id, undef, 'sample id is undefined');
  is ($l->sample_name, undef, 'sample name is undefined');
  is ($l->study_id, undef, 'study id is undefined');
  is ($l->study_name, undef, 'study name is undefined');
  is ($l->default_tag_sequence, undef, 'barcode is undefined');
  is ($l->default_tagtwo_sequence, undef, 'no second barcode is undefined');
  is ($l->library_type, undef, 'library type is undefined');
  is ($l->lane_id, undef, 'lane id is undefined');
};

subtest 'tag zero' => sub {
  plan tests => 10;

  # There is a tag zero product record, but the driver is not using it.
  # The functionality comes from the top-level shim in st::api::lims.

  # The tests below demonstrate how the code works. To get the same
  # functionality as for Illumina tag zero, the position attribute
  # should be supplied.

  my $l = st::api::lims->new(
    id_run      => $id_run,
    tag_index   => 0,
    driver_type => 'useq_ml_warehouse',
    mlwh_schema => $schema_wh
  );
  ok ($l->is_pool, 'product is a pool');
  ok (!$l->is_control, 'product is not a control');
  is ($l->sample_id, undef, 'sample id is undefined');
  is (scalar($l->sample_ids), 0, 'multiples do not work');
  is ($l->study_id, undef, 'study id is undefined');
  is (scalar($l->study_ids), 0, 'multiples do not work');
  
  $l = st::api::lims->new(
    id_run      => $id_run,
    position    => 1,
    tag_index   => 0,
    driver_type => 'useq_ml_warehouse',
    mlwh_schema => $schema_wh
  );
  ok ($l->is_pool, 'product is a pool');
  ok (!$l->is_control, 'product is not a control');
  is (scalar($l->sample_ids), 7, 'multiples work');
  is (scalar($l->study_ids), 1, 'multiples work');
};

subtest 'using rpt_list argument' => sub { 
    plan tests => 8;
    
    my $lims = st::api::lims->new(
      rpt_list         => join(q[:], $id_run, 1, 98),
      driver_type      => 'useq_ml_warehouse',
      mlwh_schema      => $schema_wh,
    );
    my $sample_name = '6133STDY8786700';
    is ($lims->sample_name, $sample_name, 'correct sample name');
    my @children = $lims->children();
    is (@children, 1, 'one child object');
    my $child = $children[0];
    is ($child->driver_type, 'useq_ml_warehouse', 'child driver type is correct');
    is ($child->driver->mlwh_schema, $schema_wh,
      q[child's driver is using the original db connection]);
    is ($child->id_run, $id_run, 'child run is correct');
    is ($child->tag_index, 98, 'child tag index is correct');
    is ($child->position, 1, 'child position is correct');
    is ($child->sample_name, $sample_name, 'child sample name is correct');  
};

####################################################
# Switching to testing the combo driver. Product
# database entries will be dropped.
####################################################

$schema_wh->resultset('UseqProductMetric')
  ->search({id_run => $id_run})->delete();
$schema_wh->resultset('UseqRunMetric')
  ->search({id_run => $id_run})->delete();

subtest 'LIMS properties for a product - combo driver' => sub { 
  plan tests => 12;

  my $l = st::api::lims->new(
    id_run      => $id_run,
    tag_index   => 100,
    driver_type => 'useq_ml_warehouse',
    mlwh_schema => $schema_wh,
    runfolder_path => 't/data/ultimagen/433681-20260205_1327'
  );
  ok (!$l->is_pool, 'product is not a pool');
  ok (!$l->is_control, 'product is not a control');
  is ($l->sample_id, '4396728', 'sample id');
  is ($l->sample_name, '6133STDY8786709', 'sample name');
  is ($l->study_id, '2239', 'study id');
  is ($l->study_name, 'MPN Whole Genomes', 'study name');
  is ($l->default_tag_sequence, 'CGGATCATGCGTGAT', 'barcode');
  is ($l->default_tagtwo_sequence, undef, 'no second barcode');
  is ($l->library_type, 'Ultima High Throughput PCR Free 96', 'library type');
  is ($l->lane_id, '76975170', 'lane id');

  # No LIMS data for Ultimagen control, not listed in the input file either.
  $l = st::api::lims->new(
    id_run      => $id_run,
    tag_index   => $control_tag_index,
    driver_type => 'useq_ml_warehouse',
    mlwh_schema => $schema_wh,
    runfolder_path => 't/data/ultimagen/433681-20260205_1327'
  );
  ok (!$l->is_pool, 'product is not a pool');
  my $error = 'Not data corresponding to tag index 9999 in the input file ' .
              't/data/ultimagen/433681-20260205_1327/433681_LibraryInfo.xml';
  throws_ok {$l->sample_id} qr/$error/, 'error trying to represent a control';
};

subtest 'tag zero - combo driver' => sub {
  plan tests => 10;

  # See comments for this test for a pure db driver.

  my $l = st::api::lims->new(
    id_run      => $id_run,
    tag_index   => 0,
    driver_type => 'useq_ml_warehouse',
    mlwh_schema => $schema_wh,
    runfolder_path => 't/data/ultimagen/433681-20260205_1327'
  );
  ok ($l->is_pool, 'product is a pool');
  ok (!$l->is_control, 'product is not a control');
  is ($l->sample_id, undef, 'sample id is undefined');
  is (scalar($l->sample_ids), 0, 'multiples do not work');
  is ($l->study_id, undef, 'study id is undefined');
  is (scalar($l->study_ids), 0, 'multiples do not work');
  
  $l = st::api::lims->new(
    id_run      => $id_run,
    position    => 1,
    tag_index   => 0,
    driver_type => 'useq_ml_warehouse',
    mlwh_schema => $schema_wh,
    runfolder_path => 't/data/ultimagen/433681-20260205_1327'
  );
  ok ($l->is_pool, 'product is a pool');
  ok (!$l->is_control, 'product is not a control');
  is (scalar($l->sample_ids), 7, 'multiples work');
  is (scalar($l->study_ids), 1, 'multiples work');
};

1;
