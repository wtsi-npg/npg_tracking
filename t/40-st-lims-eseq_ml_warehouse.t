use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;

#####
# The tests below demonstrate the behaviour of st::api::lims class with
# the eseq_ml_warehouse driver type.

use_ok('st::api::lims');

my $schema_wh;
lives_ok { $schema_wh = Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/])->new_object({})->create_test_db(
    q[WTSI::DNAP::Warehouse::Schema],q[t/data/fixtures_lims_wh_samplesheet]) 
} 'ml_warehouse test db created';

subtest 'no product table entries' => sub {
  plan tests => 4;

  my $init = {
    id_run => 2,
    driver_type => 'eseq_ml_warehouse',
    mlwh_schema => $schema_wh
  };

  lives_ok { st::api::lims->new($init) } 'object creation is OK';

  my $package = 'st::api::lims::eseq_ml_warehouse';
  throws_ok { st::api::lims->new($init)->children() }
    qr/No product records for $package id_run 2/,
    'error calling a method that requires db data present';

  $init->{position} = 1;
  throws_ok { st::api::lims->new($init)->children }
    qr/No product records for $package id_run 2, position 1/,
    'error calling a method that requires db data present';

  $init->{tag_index} = 1;
  throws_ok { st::api::lims->new($init)->is_control }
    qr/No database record retrieved/,
    'error calling a method that requires db data present';
};

subtest 'family tree, product table entries are present' => sub {
  plan tests => 174;

  for my $id_run ((50805, 51922)) {
    note "Considering run $id_run";
    my $l = st::api::lims->new(
      id_run      => $id_run,
      driver_type => 'eseq_ml_warehouse',
      mlwh_schema => $schema_wh
    );
    ok (!$l->is_pool, 'run is not a pool');

    my $num_lanes = ($id_run == 50805) ? 1 : 2;
    my @lanes = $l->children();
    is (scalar @lanes, $num_lanes, 'correct number of lane child objects');
    is ($l->num_children, $num_lanes, "number of children is $num_lanes");
    my $count = 0;
    for my $lane (@lanes) {
      $count++;
      is ($lane->driver_type, 'eseq_ml_warehouse', 'driver type is correct');
      is ($lane->driver->mlwh_schema, $schema_wh, 'original db connection is used');
      ok ($lane->is_pool, 'lane is a pool');
      is ($lane->position, $count, "position is $count");
      is ($lane->id_run, $id_run, 'id_run is propagated');
      ok (!$lane->tag_index, 'tag index is not defined');
      ok (!$lane->is_control, 'lane is not control');
      is ($lane->spiked_phix_tag_index, 1, 'control tag index is 1');

      my @children = $lane->children();
      is (scalar @children, 5, '5 plex child objects');
      is ($lane->num_children, 5, 'num_children is 5');
      is (join(q[,], map { $_->tag_index } @children), '1,2,3,4,5',
        'correct order of plex children');

      my $pcount = 0;
      for my $plex (@children) {
        $pcount++;
        is ($plex->driver_type, 'eseq_ml_warehouse', 'driver type is correct');
        is ($plex->driver->mlwh_schema, $schema_wh, 'original db connection is used');
        ok (!$plex->is_pool, 'not a pool');
        is ($plex->position, $count, "position is $count");
        is ($plex->id_run, $id_run, 'id_run is propagated');
        is ($plex->tag_index, $pcount, "tag index is $pcount");
        is ($plex->is_control, ($pcount == 1) ? 1 : 0, 'control flag is correctly set');
        is ($plex->spiked_phix_tag_index, 1, 'control tag index is 1');
        is ($plex->num_children, 0, 'num_children is 0');
      }
    }
  }
};

subtest 'LIMS properties for a product' => sub { 
  plan tests => 20;

  my $l = st::api::lims->new(
    id_run      => 51922,
    position    => 1,
    tag_index   => 3,
    driver_type => 'eseq_ml_warehouse',
    mlwh_schema => $schema_wh
  );
  ok (!$l->is_pool, 'product is not a pool');
  ok (!$l->is_control, 'product is not a control');
  is ($l->sample_id, '4396719', 'sample id');
  is ($l->sample_name, '6133STDY8786700', 'sample name');
  is ($l->study_id, '2239', 'study id');
  is ($l->study_name, 'MPN Whole Genomes', 'study name');
  is ($l->default_tag_sequence, 'CTTGCTAG', 'barcode');
  is ($l->default_tagtwo_sequence, 'TCATCTCC', 'second barcode');
  is ($l->library_type, 'PCR with TruSeq tails amplicon', 'library type');
  is ($l->lane_id, '77167532', 'lane id');

  # No LIMS data for Elembio controls.
  # Normally there are four controls per lane, the same sample with different
  # barcodes. The barcodes are recorded in the eseq_product_metrics table,
  # so with the current way of retrieving them from the iseq_flowcell table are
  # undefined.
  $l = st::api::lims->new(
    id_run      => 51922,
    position    => 1,
    tag_index   => 1,
    driver_type => 'eseq_ml_warehouse',
    mlwh_schema => $schema_wh
  );
   ok (!$l->is_pool, 'product is not a pool');
   ok ($l->is_control, 'product is a control');
   is ($l->sample_id, undef, 'sample id is undefined');
   is ($l->sample_name, undef, 'sample name is undefined');
   is ($l->study_id, undef, 'study id is undefined defined');
   is ($l->study_name, undef, 'study name is undefined');
   is ($l->default_tag_sequence, undef, 'barcode is undefined');
   is ($l->default_tagtwo_sequence, undef, 'no second barcode is undefined');
   is ($l->library_type, undef, 'library type is undefined');
   is ($l->lane_id, undef, 'lane id is undefined');
};

subtest 'tag zero object' => sub {
  plan tests => 7;

  # There is a tag zero product record in MLWH, but the driver is not using it.
  # The functionality comes from the top-level shim in st::api::lims.

  my $l = st::api::lims->new(
    id_run      => 51922,
    position    => 1,
    tag_index   => 0,
    driver_type => 'eseq_ml_warehouse',
    mlwh_schema => $schema_wh
  );
  ok ($l->is_pool, 'tag zero is a pool');
  is ($l->num_children, 5, '5 children');
  ok (!$l->is_control, 'tag zero is not a control');
  is ($l->sample_id, undef, 'sample id is undefined');
  is (scalar($l->sample_ids), 4, 'multiples work, four sample IDs');
  is ($l->study_id, 2239, 'study id is defined');
  is (scalar($l->study_ids), 1, 'multiples work');
};

subtest 'using rpt_list argument' => sub { 
  plan tests => 8;
    
  my $lims = st::api::lims->new(
    rpt_list         => '51922:1:3;51922:2:3',
    driver_type      => 'eseq_ml_warehouse',
    mlwh_schema      => $schema_wh,
  );
  my $sample_name = '6133STDY8786700';
  is ($lims->sample_name, $sample_name, 'correct sample name');
  my @children = $lims->children();
  is (@children, 2, 'two child objects');
  my $child = $children[0];
  is ($child->driver_type, 'eseq_ml_warehouse', 'child driver type is correct');
  is ($child->driver->mlwh_schema, $schema_wh,
    q[child's driver is using the original db connection]);
  is ($child->id_run, 51922, 'child id_run is correct');
  is ($child->tag_index, 3, 'child tag index is correct');
  is ($child->position, 1, 'child position is correct');
  is ($child->sample_name, $sample_name, 'child sample name is correct');  
};

1;
