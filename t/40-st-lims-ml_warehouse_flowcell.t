use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;

use_ok('st::api::lims');

my $schema_wh;
lives_ok { $schema_wh = Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/])->new_object({})->create_test_db(
    q[WTSI::DNAP::Warehouse::Schema], q[t/data/fixtures_lims_wh_samplesheet])
} 'ml_warehouse test db created';

subtest 'Illumina flowcell lookup' => sub {
  plan tests => 6;

  my $l = st::api::lims->new(
    id_flowcell_lims => 13994,
    driver_type      => 'ml_warehouse_flowcell',
    mlwh_schema      => $schema_wh,
  );

  is($l->driver->manufacturer, 'Illumina', 'manufacturer is Illumina');
  ok($l->driver->count, 'batch-level object has rows');

  my @lanes = $l->children;
  is(scalar @lanes, 1, 'one lane child');
  ok($lanes[0]->is_pool, 'lane is a pool');

  my @plexes = $lanes[0]->children;
  ok(@plexes, 'lane has plex children');
  is($plexes[0]->tag_index, 1, 'first plex tag index is propagated');
};

subtest 'Elembio flowcell lookup' => sub {
  plan tests => 8;

  my $l = st::api::lims->new(
    id_flowcell_lims => 107441,
    driver_type      => 'ml_warehouse_flowcell',
    mlwh_schema      => $schema_wh,
  );

  is($l->driver->manufacturer, 'Element Biosciences',
    'manufacturer is Element Biosciences');
  is($l->id_run, 51922, 'run id is resolved from linked product metrics');

  my @lanes = $l->children;
  is(scalar @lanes, 2, 'two lane children');

  my @plexes = $lanes[0]->children;
  is(join(q[,], map { $_->tag_index } @plexes), '2,3,4,5',
    'lane one flowcell-linked tag indices are correct');

  my $plex = st::api::lims->new(
    id_flowcell_lims => 107441,
    position         => 1,
    tag_index        => 3,
    driver_type      => 'ml_warehouse_flowcell',
    mlwh_schema      => $schema_wh,
  );
  ok(!$plex->is_control, 'flowcell-linked plex is not control');
  is($plex->sample_name, '6133STDY8786700', 'sample name is correct');
  is($plex->study_name, 'MPN Whole Genomes', 'study name is correct');
  is($plex->default_tagtwo_sequence, 'TCATCTCC', 'second barcode is correct');
};

subtest 'Ultima flowcell lookup' => sub {
  plan tests => 6;

  my $l = st::api::lims->new(
    id_flowcell_lims => '107185_NT1882031W_2',
    driver_type      => 'ml_warehouse_flowcell',
    mlwh_schema      => $schema_wh,
  );

  is($l->driver->manufacturer, 'Ultima Genomics',
    'manufacturer is Ultima Genomics');
  is($l->id_run, 51815, 'run id is resolved from linked product metrics');

  my @products = $l->children;
  is(scalar @products, 7, 'seven wafer-linked products');

  my $product = st::api::lims->new(
    id_flowcell_lims => '107185_NT1882031W_2',
    tag_index        => 100,
    driver_type      => 'ml_warehouse_flowcell',
    mlwh_schema      => $schema_wh,
  );
  ok(!$product->is_control, 'product is not a control');
  is($product->sample_name, '6133STDY8786709', 'sample name is correct');
  is($product->default_tag_sequence, 'CGGATCATGCGTGAT', 'barcode is correct');
};

subtest 'Ultima wafer lookup without product metrics' => sub {
  plan tests => 8;

  my $l = st::api::lims->new(
    id_flowcell_lims => '107186_NT1882031W_1',
    driver_type      => 'ml_warehouse_flowcell',
    mlwh_schema      => $schema_wh,
  );

  is($l->driver->manufacturer, 'Ultima Genomics',
    'manufacturer is Ultima Genomics');
  is($l->id_run, undef, 'run id is undefined without product metrics');

  my @products = $l->children;
  is(scalar @products, 2, 'two wafer-linked products');
  is(join(q[,], map { $_->tag_index } @products), '1,2',
    'tag indices are derived from wafer rows');

  my $product = st::api::lims->new(
    id_flowcell_lims => '107186_NT1882031W_1',
    tag_index        => 1,
    driver_type      => 'ml_warehouse_flowcell',
    mlwh_schema      => $schema_wh,
  );
  is($product->sample_name, '6133STDY8786700', 'sample name is from wafer row');
  is($product->default_tag_sequence, 'AAAA',
    'first derived tag index maps to first tag sequence by sort order');
  is($product->qc_state, undef, 'qc state is undefined without product metrics');
  is($product->spiked_phix_tag_index, undef,
    'spiked PhiX tag index is undefined without product metrics');
};

1;
