use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;
use Test::Warn;
use Test::Deep;
use Moose::Meta::Class;

my $mlwh_d      = 'st::api::lims::ml_warehouse';
my $mlwh_auto_d = 'st::api::lims::ml_warehouse_auto';
use_ok($mlwh_d);
use_ok($mlwh_auto_d);

my $schema_wh;
lives_ok { $schema_wh = Moose::Meta::Class->create_anon_class(
  roles => [qw/npg_testing::db/])->new_object({})->create_test_db(
  q[WTSI::DNAP::Warehouse::Schema],q[t/data/fixtures_stlims_wh]) 
} 'ml_warehouse test db created';

subtest 'constructing objects' => sub {
  plan tests => 34;

        for my $d ($mlwh_d, $mlwh_auto_d) {

  my $m = ($d =~ /_auto$/) ? 'id_flowcell_lims, flowcell_barcode or id_run' :
                             'id_flowcell_lims or flowcell_barcode';
  throws_ok {$d->new(
    mlwh_schema => $schema_wh)->query_resultset}
    qr/Either $m should be defined/,
    'error when no flowcell attributes are given';

  my $rs;
  throws_ok {$rs = $d->new(
      mlwh_schema      => $schema_wh,
      flowcell_barcode => 'barcode')->query_resultset}
qr/No record retrieved for st::api::lims::ml_warehouse flowcell_barcode barcode/,
    'error when non-existing barcode is given';

  throws_ok {$rs = $d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => 'XX_99_XX')->query_resultset}
qr/No record retrieved for st::api::lims::ml_warehouse id_flowcell_lims XX_99_XX/,
    'error when non-existing flowcell id is given';

  throws_ok {
    $rs = $d->new(
      mlwh_schema      => $schema_wh,
      flowcell_barcode => '42UMBAAXX',
      id_flowcell_lims => 'XX_99_XX')->query_resultset
  }
qr/No record retrieved for st::api::lims::ml_warehouse flowcell_barcode 42UMBAAXX, id_flowcell_lims XX_99_XX/,
  'error retrieving data with valid barcode and invalid flowcell id';

  ok ($d->new(
      mlwh_schema      => $schema_wh,
      flowcell_barcode => '42UMBAAXX')->query_resultset->count,
   'data retrieved for existing barcode');
  is ($d->new(
      mlwh_schema      => $schema_wh,
      flowcell_barcode => '42UMBAAXX')->id_run, 3905, 'find id_run if in product metrics table');
  ok ($d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => 4775)->query_resultset->count,
    'data retrieved for existing flowcell id supplied as an integer');
  ok ($d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775')->query_resultset->count,
    'data retrieved for existing flowcell id supplied as a string');
  is ($d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775')->id_run, 3905, 'find id_run if in product metrics table');
  my $product_metrics_row = st::api::lims::ml_warehouse->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775')->query_resultset()->next()->iseq_product_metrics()->next();
  $product_metrics_row->update({id_run => 3906});
  throws_ok { $d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775')->id_run }
    qr/Found more than one \(2\) id_run/,
    'error finding id_run if multiple values found';
  lives_ok {$d->new(
      id_run           => 3905,
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775')->id_run}
    'no checks when the value is set by the caller';

  ok ($d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => 22043,
      flowcell_barcode => 'barcode')->query_resultset->count,
    'data retrieved as long as flowcell id is valid');
  my $id_run;
  warning_like { $id_run = $d->new(
      mlwh_schema      => $schema_wh,
      flowcell_barcode => 'barcode')->id_run }
    qr/No id_run set yet/,
    'warning finding id_run if not in product metrics table';
  is($id_run, undef, 'run id undefined');
  throws_ok { $d->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => 22043,
                                 position         => 2)->query_resultset}
qr/No record retrieved for st::api::lims::ml_warehouse id_flowcell_lims 22043, position 2/,
    'error when lane does not exist';

  ok ($d->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => 22043,
                                 position         => 1)->query_resultset->count,
    'data retrieved for existing lane');
  throws_ok { $d->new(
                                 mlwh_schema      => $schema_wh,
                                 id_flowcell_lims => 22043,
                                 position         => 1,
                                 tag_index        => 326)->query_resultset}
qr/No record retrieved for st::api::lims::ml_warehouse id_flowcell_lims 22043, position 1, tag_index 326/,
    'error when tag index does not exist';
  
  $product_metrics_row->update({id_run => 3905});
        }
};

subtest 'lane-level driver from run-level driver' => sub {
  plan tests => 81;

  my $count = 0;
        for my $p ($mlwh_d, $mlwh_auto_d, $mlwh_auto_d) {

  $count++;
  my $d;

  if ($count < 3) {
    $d = $p->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775');
  } else {
    $d = $p->new(
      mlwh_schema      => $schema_wh,
      id_run           => 3905);
  }
  isa_ok ($d, ($count == 1) ? 'st::api::lims::ml_warehouse' : 'st::api::lims::ml_warehouse_auto');
  my @children = $d->children;
  my %types;
  my @positions = ();
  map { $types{ref $_} = 1; push @positions, $_->position} @children;
  is (join(q[,], keys %types),
    ($count == 1) ? 'st::api::lims::ml_warehouse' : 'st::api::lims::ml_warehouse_auto',
    'children have correct class');
  is (join(q[,], @positions), '1,2,3,4,5,6,7,8', 'eight children sorted by position');
  ok (!$d->is_control, 'not control');
  ok (!$d->is_pool, 'not pool');
  ok (!$d->study_name, 'no study name');
  ok (!$d->sample_id, 'no sample_id');
  ok (!$d->sample_supplier_name, 'no supplier name');
  ok (!$d->sample_cohort, 'no cohort');
  ok (!$d->sample_donor_id, 'no donor id');
  is ($d->default_tag_sequence, undef, 'first index sequence undefined');
  is ($d->default_tagtwo_sequence, undef, 'second index sequence undefined');

  my $lims1 = $children[0];
  ok (!$lims1->is_control, 'first lane is not control');
  ok (!$lims1->is_pool, 'first lane is not a pool');
  ok (!$lims1->children, 'children list is empty');
  is ($lims1->lane_id, 21582, 'lane id');
  cmp_ok($lims1->library_id, q(eq), '999999', 'lib id');
  cmp_ok($lims1->library_name, q(eq), '999999', 'lib name');
  ok(!$lims1->sample_consent_withdrawn(), 'sample consent not withdrawn');
  is ($lims1->sample_id, 7283, 'sample id');
  is ($lims1->sample_supplier_name, 'sample_33', 'supplier name');
  is ($lims1->sample_cohort, 'plan2', 'cohort');
  is ($lims1->sample_donor_id, 'd5678', 'donor id');
  is ($lims1->purpose, 'qc', 'purpose');

  my $insert_size;
  lives_ok {$insert_size = $lims1->required_insert_size_range} 'insert size for the first lane';
  is ($insert_size->{'from'}, 300, 'required FROM insert size');
  is ($insert_size->{'to'}, 400, 'required TO insert size');
        }
};

subtest 'lane-level drivers' => sub {
  plan tests => 82;

 is( $schema_wh->resultset('IseqFlowcell')
     ->search({id_flowcell_lims => '4775', tag_index => undef})->count(), 8,
     'flowcell table does not define tag indices');

  my $count = 0;
        for my $p ($mlwh_d, $mlwh_auto_d, $mlwh_auto_d, $mlwh_auto_d) {

  $count++;

  if ($count == 4) {
    $schema_wh->resultset('IseqFlowcell')
      ->search({id_flowcell_lims => '4775', position => [4,6]})->
      update({tag_index => 1});
    diag 'test one-tag pool that was sequenced without reading the index read';
    is( $schema_wh->resultset('IseqFlowcell')
      ->search({id_flowcell_lims => '4775', tag_index => 1})->count(),
      2, 'two tag indexes are set');
  }

  my ($lims4, $lims6);

  if ($count < 3) {
    $lims4 = $p->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775',
      position         => 4);
    $lims6 = $p->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775',
      position         => 6);
  } else {
    $lims4 = $p->new(
      mlwh_schema      => $schema_wh,
      id_run           => 3905,
      position         => 4);
    $lims6 = $p->new(
      mlwh_schema      => $schema_wh,
      id_run           => 3905,
      position         => 6);
  }

  is ($lims4->is_control, 1, 'is control');
  is ($lims4->is_pool, 0, 'not pool');
  ok (!$lims4->children, 'children list is empty');
  is ($lims4->lane_id, 3314798, 'lane id');
  is ($lims4->library_id, 79577, 'control id from fourth lane');
  is ($lims4->library_name, 79577, 'control name from fourth lane');
  is ($lims4->sample_id, 9836, 'sample id from fourth lane');
  ok (!$lims4->study_id, 'study id from fourth lane undef');
  ok (!$lims4->required_insert_size_range, 'no insert size for control lane');
  is ($lims4->purpose, 'standard', 'purpose');

  is ($lims6->library_id, 556677, 'new library id returned');
  is ($lims6->library_name, 556677, 'library name is based on the new library id');  
  is ($lims6->study_id, 333, 'study id');
  cmp_ok ($lims6->study_name, q(eq), q(CLL whole genome), 'study name');

  cmp_bag ($lims6->email_addresses,['clowdy@sanger.ac.uk', 'rainy@sanger.ac.uk', 'stormy@sanger.ac.uk', 'sunny@sanger.ac.uk'],'All email addresses');
  cmp_bag ($lims6->email_addresses_of_managers,[qw(sunny@sanger.ac.uk)],'Managers email addresses');
  is_deeply ($lims6->email_addresses_of_followers,[qw(clowdy@sanger.ac.uk rainy@sanger.ac.uk stormy@sanger.ac.uk)],'Followers email addresses');
  is_deeply ($lims6->email_addresses_of_owners,[qw(sunny@sanger.ac.uk)],'Owners email addresses');

  is ($lims6->study_alignments_in_bam, 1,'do bam alignments');
  is ($lims6->tag_index, undef, 'tag index is undefined');

        }
};

sub _add2query {
  my ($query, $count, $lims_id, $id_run) = @_;
  if ($count < 3) {
    $query->{'id_flowcell_lims'} = $lims_id;
  } else {
    $query->{'id_run'} = $id_run;
  } 
}

subtest 'lane and tag level drivers' => sub {
  plan tests => 102;

  my $lims_id = 16249;
  my $id_run  = 45678;
  my $pos     = 1;

  my $fcrs = $schema_wh->resultset('IseqFlowcell')->search(
   { id_flowcell_lims => $lims_id, position => 1});
  my $prs = $schema_wh->resultset('IseqProductMetric');
  while (my $row = $fcrs->next) {
    $prs->create({id_iseq_flowcell_tmp => $row->id_iseq_flowcell_tmp,
                  tag_index            => $row->tag_index,
                  position             => $pos,
                  id_run               => $id_run});
  }

  my $count  = 0;
        for my $p ($mlwh_d, $mlwh_auto_d, $mlwh_auto_d) {

  $count++;

  my $query = { mlwh_schema      => $schema_wh,
                position         => $pos };
  _add2query($query, $count, $lims_id, $id_run);  
  my $lims = $p->new($query);
  ok (!$lims->bait_name, 'bait name undefined');
  ok ($lims->is_pool, 'lane is a pool');
  ok (!$lims->sample_supplier_name, 'no supplier name');
  ok (!$lims->sample_cohort, 'no cohort');
  ok (!$lims->sample_donor_id, 'no donor id');
  ok (!$lims->is_control, 'lane is not control');
  is (scalar $lims->children, 9, 'nine-long children list');
  is ($lims->spiked_phix_tag_index, 168, 'spike index');

  $query = { mlwh_schema      => $schema_wh,
             position         => $pos,
             tag_index        => 0,
           };
  _add2query($query, $count, $lims_id, $id_run);
  $lims = $p->new($query);
  ok (!$lims->bait_name, 'bait name undefined');
  ok ($lims->is_pool, 'tag zero is a pool');
  ok (!$lims->is_control, 'tag zero is not control');
  is (scalar $lims->children, 9, 'tag zero - nine-long children list');
  is ($lims->spiked_phix_tag_index, 168, 'spike index');
  ok (!$lims->sample_supplier_name, 'no supplier name');
  ok (!$lims->sample_cohort, 'no cohort');
  ok (!$lims->sample_donor_id, 'no donor id');
  is ($lims->default_tag_sequence, undef, 'first index sequence undefined');
  is ($lims->default_tagtwo_sequence, undef, 'second index sequence undefined');

  $query = { mlwh_schema      => $schema_wh,
             position         => $pos,
             tag_index        => 2,  
           };
  _add2query($query, $count, $lims_id, $id_run);
  $lims = $p->new($query);
  is($lims->bait_name, 'Human all exon 50MB', 'bait name for a plex');
  is ($lims->spiked_phix_tag_index, 168, 'spike index');
  ok (!$lims->children, 'children list is empty');
  ok (!$lims->is_control, 'tag 2 is not control');
  is ($lims->sample_id, 1092803, 'sample id');
  is ($lims->sample_supplier_name, 'sample_33', 'supplier name');
  is ($lims->sample_cohort, 'plan1', 'cohort');
  is ($lims->sample_donor_id, '5678', 'donor id');
  is ($lims->default_tag_sequence, 'CGATGT', 'first index sequence');
  is ($lims->default_tagtwo_sequence, undef, 'second index sequence undefined');

  $query = { mlwh_schema      => $schema_wh,
             position         => $pos,
             tag_index        => 168,  
           };
  _add2query($query, $count, $lims_id, $id_run);
  $lims = $p->new($query);
  is ($lims->bait_name, undef, 'bait name undefined for spiked phix plex');
  ok (!$lims->is_pool, 'is not a pool');
  ok ($lims->is_control, 'tag 168 is control');
  is ($lims->spiked_phix_tag_index, 168, 'spike index');
  is ($lims->default_tag_sequence, 'ACAACGCAAT', 'first index sequence');
  is ($lims->default_tagtwo_sequence, undef, 'second index sequence undefined');
        }
};

subtest 'lave and tag level drivers' => sub {
  plan tests => 33;

  my $id_run  = 99789;
  my $lims_id = 15728;
  my $fcrs = $schema_wh->resultset('IseqFlowcell')->search({ id_flowcell_lims => $lims_id});
  my $prs = $schema_wh->resultset('IseqProductMetric');
  while (my $row = $fcrs->next) {
    $prs->create({id_iseq_flowcell_tmp => $row->id_iseq_flowcell_tmp,
                  tag_index            => $row->tag_index,
                  position             => $row->position,
                  id_run               => $id_run});
  }

  my $count = 0;
        for my $d ($mlwh_d, $mlwh_auto_d, $mlwh_auto_d) {

  $count++;

  my $query = {mlwh_schema      => $schema_wh};
  _add2query($query, $count, $lims_id, $id_run);
  my $lims = $d->new($query);
  is (scalar $lims->children, 8, '8 child lanes');

  $query = {mlwh_schema      => $schema_wh,
            position         => 1};
  _add2query($query, $count, $lims_id, $id_run);
  $lims = $d->new($query);
  my @children = $lims->children;
  is (scalar @children, 9, 'nine child plexes');
  my %types;
  map { $types{ref $_} = 1 } @children;
  is (join(q[,], keys %types),
    ($count == 1) ? 'st::api::lims::ml_warehouse' : 'st::api::lims::ml_warehouse_auto',
    'children have correct class');

  $query = {mlwh_schema      => $schema_wh,
            position         => 1,
            tag_index        => 3};
  _add2query($query, $count, $lims_id, $id_run);
  $lims = $d->new($query);
  is( $lims->sample_id, 1299694, 'sample id');
  is( $lims->default_tag_sequence, 'TTAGGC', 'tag sequence');
  is( $lims->default_tagtwo_sequence, undef, 'second index sequence undefined');
  is( $lims->default_library_type, 'Agilent Pulldown', 'library type');
  is( $lims->bait_name, 'DDD custom library', 'bait name');
  is( $lims->project_cost_code, 'S0802', 'project code code');
  is( $lims->sample_reference_genome, 'Not suitable for alignment', 'sample ref genome');
  ok( $lims->sample_consent_withdrawn(), 'sample consent withdrawn' );
        }
};

subtest 'lave and tag level drivers' => sub {
  plan tests => 74;

  my $rs = $schema_wh->resultset('IseqFlowcell');
  my $row = $rs->search({id_flowcell_lims => 22043, position=>1, tag_index=>1})->first;
  $row->set_column('tag2_sequence', 'ACGTAA');
  $row->update();

  $row = $rs->search({id_flowcell_lims => 22043, position=>1, tag_index=>96})->first;
  $row->set_column('tag_sequence', 'ACGTAAACGTACCTGA');
  $row->update();

        for my $d ($mlwh_d, $mlwh_auto_d) {

  my $lims = $d->new( mlwh_schema      => $schema_wh,
                      id_flowcell_lims => 22043);

  my @lanes = $lims->children;
  is (scalar @lanes, 1, 'one lane returned');
  my $lane = $lanes[0];
  is ($lane->position, 1, 'position is 1');
  is ($lane->is_pool, 1, 'is_pool true on lane level');
  ok (!$lane->is_control, 'not a control lane');
  is ($lane->library_id, undef, 'library_id indefined for a pool');
  is ($lane->spiked_phix_tag_index, undef, 'spike index undefined');
  my @plexes;
  lives_ok {@plexes = $lane->children}  'can get plex-level objects';
  is (scalar @plexes, 96, '96 plexes returned');
  is ($plexes[0]->position, 1, 'position of the first plex is 1');
  is ($plexes[0]->tag_index, 1, 'tag_index of the first plex is 1');
  is ($plexes[0]->lane_id, 8015825, 'lane id');
  is ($plexes[0]->library_id, 7583507, 'library_id of the first plex');
  is ($plexes[0]->sample_name, 'first', 'sample_name of the first plex');
  is ($plexes[0]->sample_id, 1650304, 'sample_id of the first plex');
  is ($plexes[0]->sample_reference_genome, 'Anopheles_gambiae (PEST)', 'sample ref genome');
  is ($plexes[0]->study_reference_genome, ' ', 'study ref genome undefined');
  is ($plexes[0]->is_pool, 0, 'is_pool false on plex level');
  is ($plexes[0]->is_control, 0, 'is_control false on for a plex');
  is ($plexes[0]->default_tag_sequence, 'ATCACGTT', 'first default tag sequence');
  is ($plexes[0]->default_tagtwo_sequence, 'ACGTAA', 'second default tag sequence');
  is ($plexes[0]->spiked_phix_tag_index, undef, 'spike index undefined');

  is ($plexes[1]->study_id, 2077, 'plex study_id');
  is ($plexes[1]->sample_reference_genome, 'Anopheles_gambiae (PEST)', 'sample ref genome undefined');
  is ($plexes[1]->study_reference_genome, ' ', 'study ref genome');

  is ($plexes[95]->position, 1, 'position of the last plex is 1');
  is ($plexes[95]->tag_index, 96, 'tag_index of the last plex is 96');
  is ($plexes[95]->default_tag_sequence, 'ACGTAAACGTACCTGA', 'first tag sequence of the last plex');
  is ($plexes[95]->default_tagtwo_sequence, undef, 'second tag sequence undefined');
  ok (!defined $plexes[95]->library_id, 'library_id of the last plex undefined');
  ok (!defined $plexes[95]->library_name, 'library_name of the last plex undefined');
  is ($plexes[95]->sample_name, 'second', 'sample_name of the last plex');
  ok (!defined $plexes[95]->study_id, 'study id undefined');
  ok (!defined $plexes[95]->study_name, 'study name undefined');
  cmp_bag ($plexes[95]->email_addresses,[],'no study - no email addresses');
  cmp_bag ($plexes[95]->email_addresses_of_managers,[],'no study - no email addresses');
  is_deeply ($plexes[95]->email_addresses_of_followers,[],'no study - no email addresses');
  is_deeply ($plexes[95]->email_addresses_of_owners,[],'no study - no email addresses');
        };
};

subtest 'multiple flowcell identifies error' => sub {
  plan tests => 2;

  for my $d ($mlwh_d, $mlwh_auto_d) {

    my $rs = $schema_wh->resultset('IseqFlowcell');
    my $row = $rs->search({flowcell_barcode => '42UMBAAXX', position=>1})->next;
    my $old = $row->id_flowcell_lims;
    $row->set_column('id_flowcell_lims', $row->id_flowcell_lims+5);
    $row->update();
  
    my $l = st::api::lims::ml_warehouse->new(
      mlwh_schema      => $schema_wh,
      flowcell_barcode => '42UMBAAXX');
    my $error = join qq[\n], 'Multiple flowcell identifies:',
      'id_flowcell_lims:flowcell_barcode', "'4775':'42UMBAAXX'", "'4780':'42UMBAAXX'";         
    throws_ok { $l->children } qr/$error/,
      'error for multiple flowcell ids';
    $row->set_column('id_flowcell_lims', $old);
    $row->update();
  }
};

subtest 'qc outcomes' => sub {
  plan tests => 21;
  
  #lanes 2-8 are converted to plexes for lane 2 
  for my $p ((2 .. 8)) {
    $schema_wh->resultset('IseqProductMetric')
              ->search({id_run => 3905, position => $p})
              ->update({tag_index => $p});
    $schema_wh->resultset('IseqFlowcell')
              ->search({id_flowcell_lims => 4775, position => $p})
              ->update({tag_index => $p});
  }
  for my $p ((2 .. 8)) {
    $schema_wh->resultset('IseqProductMetric')
              ->search({id_run => 3905, position => $p})
              ->update({position => 2});
    my $lt = ($p == 8) ? 'library_indexed_spike' : 'library_indexed';
    $schema_wh->resultset('IseqFlowcell')
              ->search({id_flowcell_lims => 4775, position => $p})
              ->update({position => 2, entity_type => $lt});
  }
  
  my $d = $mlwh_d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775',
      position         => 1);
  is ($d->qc_state, undef, 'qc state not set for a lane');
  $schema_wh->resultset('IseqProductMetric')
            ->search({id_run => 3905, position => 1})
            ->update({qc => 0});
  is ($d->qc_state, 0, 'lane failed qc');
  $schema_wh->resultset('IseqProductMetric')
            ->search({id_run => 3905, position => 1})
            ->update({qc => 1});
  ok (!$d->is_pool, 'lane is not a pool');
  is ($d->qc_state, 1, 'lane passed qc');

  $d = $mlwh_d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775',
      position         => 2);
  my $dzero = $mlwh_d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775',
      position         => 2,
      tag_index        => 0);
  ok ($d->is_pool, 'lane 2 is a pool');
  is ( scalar (grep { defined }  map {$_->qc_state} $d->children),
       0, 'all plex values undefined');
  is ($d->qc_state, undef, 'pool qc state not set');
  is ($dzero->qc_state, undef, 'tag 0 qc state not set');

  $schema_wh->resultset('IseqProductMetric')
            ->search({id_run => 3905, position => 2})
            ->update({qc => 0}); # convert all tags to a fail
  $d = $mlwh_d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775',
      position         => 2);
  $dzero = $mlwh_d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775',
      position         => 2,
      tag_index        => 0);
  is ( join(q[ ], map {$_->qc_state} $d->children),
       '0 0 0 0 0 0 0', 'all plexes failed');
  is ($d->qc_state, undef, 'pool qc undef');
  is ($dzero->qc_state, undef, 'tagzero qc undef');

  $schema_wh->resultset('IseqProductMetric')
            ->search({id_run => 3905, position => 2})
            ->update({qc => 1}); # convert all tags to a pass
  $d = $mlwh_d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775',
      position         => 2);
  $dzero = $mlwh_d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775',
      position         => 2,
      tag_index        => 0);
  is ( join(q[ ], map {$_->qc_state} $d->children),
       '1 1 1 1 1 1 1', 'all plexes passed');
  is ($d->qc_state, undef, 'pool qc undef');
  is ($dzero->qc_state, undef, 'tagzero qc undef');
  
  $schema_wh->resultset('IseqProductMetric')
             ->search({id_run => 3905, position => 2, tag_index => 2})
             ->update({qc => 0}); # convert one tag to a fail
  $d = $mlwh_d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775',
      position         => 2);
  $dzero = $mlwh_d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775',
      position         => 2,
      tag_index        => 0);
  is ( join(q[ ], map {$_->qc_state} $d->children),
       '0 1 1 1 1 1 1', 'a mixture of passed and failed plexes');
  is ($d->qc_state, undef, 'pool qc undefined');
  is ($dzero->qc_state, undef, 'tagzero qc undefined');

  # delete product metrics rows for a run
  $schema_wh->resultset('IseqProductMetric')
             ->search({id_run => 3905})->delete();
  $d = $mlwh_d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775',
      position         => 1);
  is ($d->qc_state, undef, 'lane qc undefined');
  $d = $mlwh_d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775',
      position         => 2);
  is ($d->qc_state, undef, 'pool qc undefined');
  $dzero = $mlwh_d->new(
      mlwh_schema      => $schema_wh,
      id_flowcell_lims => '4775',
      position         => 2,
      tag_index        => 0);
  is ($dzero->qc_state, undef, 'tagzero qc undefined');
  is ( scalar (grep { defined }  map {$_->qc_state} $d->children),
       0, 'all plex values undefined');
};

1;
