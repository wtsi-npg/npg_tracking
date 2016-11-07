use strict;
use warnings;

use Test::More tests => 25;
use Test::Exception;
use Test::Warn;
use File::Temp qw/ tempdir /;

my $num_delegated_methods = 45;

local $ENV{'http_proxy'} = 'http://wibble.com';

use_ok('st::api::lims');

subtest 'Class methods' => sub {
  plan tests => 10;

  is(st::api::lims->cached_samplesheet_var_name, 'NPG_CACHED_SAMPLESHEET_FILE',
    'correct name of the cached samplesheet env var');
  is(scalar st::api::lims->driver_method_list(), $num_delegated_methods, 'driver method list length');
  is(scalar st::api::lims::driver_method_list_short(), $num_delegated_methods, 'short driver method list length');
  is(scalar st::api::lims->driver_method_list_short(), $num_delegated_methods, 'short driver method list length');
  is(scalar st::api::lims::driver_method_list_short(qw/sample_name/), $num_delegated_methods-1, 'one method removed from the list');
  is(scalar st::api::lims->driver_method_list_short(qw/sample_name study_name/), $num_delegated_methods-2, 'two methods removed from the list');

  my $value = 'some other';
  is(st::api::lims->_trim_value($value), $value, 'nothing trimmed');
  is(st::api::lims->_trim_value("  $value"), $value, 'leading space trimmed');
  is(st::api::lims->_trim_value("  $value  "), $value, 'space trimmed');
  is(st::api::lims->_trim_value("  "), undef, 'white space string trimmed to undef');
};

subtest 'Setting return value for primary attributes' => sub {
  plan tests => 51;

  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/st_api_lims_new';

  my @other = qw/path id_flowcell_lims flowcell_barcode/;

  my $lims = st::api::lims->new(id_run => 6551, position => 2);
  my $lane_lims = $lims;
  for my $attr (@other) {
    is ($lims->$attr, undef, "$attr is undefined");
  }
  is ($lims->id_run, 6551, 'id run is set correctly');
  is ($lims->batch_id, 12141, 'batch id is set correctly');
  is ($lims->position, 2, 'position is set correctly');
  is ($lims->tag_index, undef, 'tag_index is undefined');
  ok ($lims->is_pool, 'lane is a pool');

  my @children = $lims->children();
  $lims = shift @children;
  for my $attr (@other) {
    is ($lims->$attr, undef, "$attr is undefined");
  }
  is ($lims->id_run, 6551, 'id run is set correctly');
  is ($lims->batch_id, 12141, 'batch id is set correctly');
  is ($lims->position, 2, 'position is set correctly');
  is ($lims->tag_index, 1, 'tag_index is set to 1');
  
  $lims = st::api::lims->new(id_run => 6551, position => 2, tag_index => 0);
  for my $attr (@other) {
    is ($lims->$attr, undef, "$attr is undefined");
  }
  is ($lims->id_run, 6551, 'id run is set correctly');
  is ($lims->batch_id, 12141, 'batch id is set correctly');
  is ($lims->position, 2, 'position is set correctly');
  is ($lims->tag_index, 0, 'tag_index is set to zero');
  ok ($lims->is_pool, 'tag zero is a pool');

  $lims = st::api::lims->new(driver => $lane_lims->driver(),
    id_run => 6551, position => 2, tag_index => 0);
  is ($lims->id_run, 6551, 'id run is set correctly');
  is ($lims->batch_id, 12141, 'batch id is set correctly');
  is ($lims->position, 2, 'position is set correctly');
  is ($lims->tag_index, 0, 'tag_index is set to zero');
  ok ($lims->is_pool, 'tag zero is a pool');

  $lims = st::api::lims->new(id_run => 6551, position => 2, tag_index => 2);
  is ($lims->tag_index, 2, 'tag_index is set correctly');

  my $path = 't/data/samplesheet/miseq_default.csv';
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = $path;

  $lims = st::api::lims->new(id_run => 6551, position => 1, tag_index => 0);
  is ($lims->driver_type, 'samplesheet', 'samplesheet driver');

  push @other, 'batch_id';
  shift @other;

  for my $attr (@other) {
    is ($lims->$attr, undef, "$attr is undefined");
  }
  is ($lims->id_run, 6551, 'id run is set correctly');
  is ($lims->path, $path, 'path is set correctly');
  is ($lims->position, 1, 'position is set correctly');
  is ($lims->tag_index, 0, 'tag_index is set to zero');
  ok ($lims->is_pool, 'tag zero is a pool');

  $lane_lims =  st::api::lims->new(id_run => 6551, position => 1);
  $lims = st::api::lims->new(driver    => $lane_lims->driver(),
                             id_run    => 6551,
                             position  => 1,
                             tag_index => 0);
  is ($lims->id_run, 6551, 'id run is set correctly');
  is ($lims->position, 1, 'position is set correctly');
  is ($lims->tag_index, 0, 'tag_index is set to zero');
  ok ($lims->is_pool, 'tag zero is a pool');
  ok (!$lims->is_composition, 'tag zero is not a composition');

  $lims = st::api::lims->new(rpt_list => '6551:1');
  my @a = @other;
  push @a, qw/id_run position tag_index/;
  is ($lims->rpt_list, '6551:1', 'rpt_list is set correctly');
  ok ($lims->is_composition, 'is a composition');
  for my $attr (@a) {
    is($lims->$attr, undef, "$attr is undefined");
  }
};

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/st_api_lims_new';

my @libs_6551_1 = ('PhiX06Apr11','SS109114 2798524','SS109305 2798523','SS117077 2798526','SS117886 2798525','SS127358 2798527','SS127858 2798529','SS128220 2798530','SS128716 2798531','SS129050 2798528','SS129764 2798532','SS130327 2798533','SS131636 2798534');
my @samples_6551_1 = qw/phiX_for_spiked_buffers SS109114 SS109305 SS117077 SS117886 SS127358 SS127858 SS128220 SS128716 SS129050 SS129764 SS130327 SS131636/;
my @accessions_6551_1 = qw/ERS024591 ERS024592 ERS024593 ERS024594 ERS024595 ERS024596 ERS024597 ERS024598 ERS024599 ERS024600 ERS024601 ERS024602/;
my @studies_6551_1 = ('Illumina Controls','Discovery of sequence diversity in Shigella sp.');

subtest 'Driver type and driver build' => sub {
  plan tests => 6;

  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/st_api_lims_new';

  use_ok('st::api::lims::samplesheet');
  lives_and( sub{
    my $lims = st::api::lims->new(id_run => 6551,
                                  driver => st::api::lims::samplesheet->new(
                                    id_run => 6551,
                                    path => $ENV{NPG_WEBSERVICE_CACHE_DIR}));
    is($lims->driver_type, 'samplesheet');
  }, 'obtain driver type from driver if driver given');

  throws_ok { st::api::lims->new(id_run => 6551, driver_type => 'some') }
    qr/Can\'t locate st\/api\/lims\/some\.pm in \@INC/,
    'unknown driver type specified - error';

  isa_ok (st::api::lims->new(id_run => 6551, driver_type => 'xml')->driver(),
    'st::api::lims::xml');
  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[];
  isa_ok (st::api::lims->new(id_run => 6551)->driver(), 'st::api::lims::xml');
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/samplesheet/miseq_default.csv';
  isa_ok (st::api::lims->new(id_run => 6551)->driver(), 'st::api::lims::samplesheet');
};

subtest 'Run-level object' => sub {
  plan tests => 19;

  my $lims = st::api::lims->new(id_run => 6551);
  is($lims->cached_samplesheet_var_name, 'NPG_CACHED_SAMPLESHEET_FILE',
    'correct name of the cached samplesheet env var');
  is(scalar $lims->driver_method_list_short(), $num_delegated_methods, 'short driver method list lenght from an object');
  is(scalar $lims->driver_method_list_short(qw/sample_name other_name/), $num_delegated_methods-1, 'one method removed from the list');
  is($lims->lane_id(), undef, q{lane_id undef for id_run 6551, not a lane} );
  is($lims->batch_id, 12141, 'batch id is 12141');
  is($lims->is_control, 0, 'not control');
  is($lims->is_pool, 0, 'not pool');
  is($lims->library_id, undef, 'no lib id');
  is($lims->seq_qc_state, undef, 'no seq qc state');
  is($lims->tag_sequence, undef, 'tag_sequence undefined');
  is($lims->tags, undef, 'tags undefined');
  is($lims->spiked_phix_tag_index, undef, 'spiked phix tag index undefined');
  is(scalar $lims->descendants, 185, '185 descendant lims');
  is(scalar $lims->children, 8, '8 child lims');
  is($lims->to_string, 'st::api::lims object, driver - xml, batch_id 12141, id_run 6551', 'object as string');
  is(scalar($lims->library_names), 0, 'batch-level library_names list empty');
  is(scalar($lims->sample_names), 0, 'batch-level sample_names list empty');
  is(scalar($lims->sample_accession_numbers), 0, 'batch-level sample_accession_numbers list empty');
  is(scalar($lims->study_names), 0, 'batch-level study_names list empty');
};

subtest 'Lane-level object' => sub {
  plan tests => 101;

  my @lims_list = ();
  push @lims_list, st::api::lims->new(id_run => 6551, position => 1);
  my @comps = ();
  foreach my $tag ((1 .. 12)) {
    push @comps, "6551:1:${tag}";
  }
  my $rpt_list = join q[;], @comps;
  push @lims_list, st::api::lims->new(rpt_list => $rpt_list);
  my $count = 0;
  foreach my $lims (@lims_list) {
    is($lims->rpt_list, $count ? $rpt_list : undef, 'rpt list value');
    is($lims->id_run,   $count ? undef     : 6551,  'id_run value');
    is($lims->position, $count ? undef     : 1,     'position value');
    is($lims->lane_id(),      $lims->rpt_list ? undef : 3065552, 'lane id');
    is($lims->batch_id,       $lims->rpt_list ? undef : 12141, 'batch id');
    is($lims->is_control,     0, 'entity is not control');
    is($lims->is_pool,        $lims->rpt_list ? undef : 1, 'pool flag value');
    is($lims->is_composition, $lims->rpt_list ? 1 : 0, 'composition flag value');
   
    is($lims->library_id, $lims->rpt_list ? undef : 2988920, 'lib id');
    is($lims->library_name, $lims->rpt_list ? undef : '297p11', 'pool lib name');
    is($lims->seq_qc_state, $lims->rpt_list ? undef : 1, 'seq qc passed');
    is($lims->tag_sequence, undef, 'tag_sequence undefined');
    is(scalar keys %{$lims->tags}, $lims->rpt_list ? 12 : 13, '13 tags defined');
    is($lims->spiked_phix_tag_index, $lims->rpt_list ? undef : 168,
      'spiked phix tag index 168');
    if (!$lims->rpt_list) {
      is($lims->tags->{$lims->spiked_phix_tag_index},
        'ACAACGCAAT', 'tag_sequence for phix');
    }
    is(scalar $lims->children, $lims->rpt_list ? 12 : 13, 'number of children');
    is($lims->num_children, $lims->rpt_list ? 12 : 13, 'number of children');

    is($lims->sample_supplier_name, undef, 'supplier sample name undefined');
    is($lims->sample_cohort, undef, 'supplier sample cohort undefined');
    is($lims->sample_donor_id, undef, 'supplier sample donor id undefined');

    my $plexes_hash = $lims->children_ia();
    my $k1 = $lims->rpt_list ? '6551:1:1' : 1;
    my $k6 = $lims->rpt_list ? '6551:1:6' : 6;
    my $p1 = $plexes_hash->{$k1};
    my $p6 = $plexes_hash->{$k6};
    is($p1->id_run,    6551, 'plex id_run');
    is($p1->position,  1,    'plex position');
    is($p1->tag_index, 1,    'plex tag index');
    ok(!$p1->is_pool, 'not a pool');
    ok(!$p1->is_composition, 'not a composition');
    is ($p1->default_tag_sequence, 'ATCACGTTAT', 'plex tag sequence');
    is($p1->sample_supplier_name, undef, 'supplier sample name undefined');
    is($p1->sample_cohort, undef, 'supplier sample cohort undefined');
    is($p1->sample_donor_id, undef, 'supplier sample donor id undefined');
    is ($p6->tag_index, 6, 'plex tag index');
    is ($p6->default_tag_sequence, 'GCCAATGTAT', 'plex tag sequence');

    is($lims->to_string, $lims->rpt_list ?
      "st::api::lims object, rpt_list $rpt_list" :
      'st::api::lims object, driver - xml, batch_id 12141, id_run 6551, position 1',
      'string respresentation of the object');

    my @libs    = @libs_6551_1;
    my @samples = @samples_6551_1;
    my @studies = @studies_6551_1;
    if ($lims->rpt_list) {
      shift @libs;
      shift @samples;
      shift @studies;
    }

    is(join(q[,], $lims->library_names), join(q[,], sort @libs),
      'top level library_names list');
    is(join(q[,], $lims->sample_names), join(q[,], sort @samples),
      'top level sample_names list');
    is(join(q[,], $lims->sample_accession_numbers), join(q[,], sort @accessions_6551_1),
      'top level sample_accession_numbers list');
    is(join(q[,], $lims->study_names), join(q[,], sort @studies),
      'top level study_names list');

    my $with_spiked_phix = 1;
    my @lib_ids    = qw/2798523 2798524 2798525 2798526 2798527 2798528
                        2798529 2798530 2798531 2798532 2798533 2798534/;
    is_deeply([$lims->library_ids($with_spiked_phix)],
      $lims->rpt_list ? [@lib_ids] : [2389196, @lib_ids],
      'top level library_ids list $with_spiked_phix = 1');
    is(join(q[,], $lims->library_names($with_spiked_phix)), join(q[,], sort @libs),
      'top level library_names list $with_spiked_phix = 1');

    my @sample_ids = qw/1093818 1093819 1093820 1093821 1093822 1093823
                        1093824 1093825 1093826 1093827 1093828 1093829/;
    is_deeply([$lims->sample_ids($with_spiked_phix)],
      $lims->rpt_list ? [@sample_ids] : [@sample_ids, 1255141], 
      'top level sample_names list $with_spiked_phix = 1');
    is(join(q[,], $lims->sample_names($with_spiked_phix)), join(q[,], sort @samples),
      'top level sample_names list $with_spiked_phix = 1');
    is(join(q[,], $lims->sample_accession_numbers($with_spiked_phix)),
      join(q[,], sort @accessions_6551_1),
      'top level sample_accession_number list $with_spiked_phix = 1');

    is(join(q[,], $lims->study_names($with_spiked_phix)), join(q[,], sort @studies),
      'top level study_names list $with_spiked_phix = 1');
    is(join(q[,], $lims->study_ids($with_spiked_phix)),
      $lims->rpt_list ? '297' : '198,297',
      'top level study_ids list $with_spiked_phix = 1');
    is(join(q[,], $lims->project_ids($with_spiked_phix)), '297',
      'top level project_ids list $with_spiked_phix = 1');

    $with_spiked_phix = 0;
    if (!$lims->rpt_list) {
      shift @libs;
      shift @samples;
      shift @studies;
    }
    is(join(q[,], $lims->library_names($with_spiked_phix)), join(q[,], sort @libs),
      'top level library_names list $with_spiked_phix = 0;');
    is(join(q[,], $lims->sample_names($with_spiked_phix)), join(q[,], sort @samples),
      'top level sample_names list $with_spiked_phix = 0;');
    is(join(q[,], $lims->sample_accession_numbers($with_spiked_phix)),
      join(q[,], sort @accessions_6551_1),
      'top level sample_accession_number list $with_spiked_phix = 0');
    is(join(q[,], $lims->study_names($with_spiked_phix)), join(q[,], sort @studies),
      'top level study_names list $with_spiked_phix = 0;');
    is(join(q[,], $lims->library_types()), 'Standard', 'top level library types list');

    is($lims->sample_consent_withdrawn, undef, 'consent withdrawn false');
    is($lims->any_sample_consent_withdrawn, 0, 'any consent withdrawn false');

    $count++;
  }
};

subtest 'Object for tag zero' => sub {
  plan tests => 27;

  my $lims = st::api::lims->new(id_run => 6551, position => 1, tag_index => 0);
  is($lims->lane_id(), undef, q{lane_id undef for id_run 6551, position 1, tag_index defined} );
  is($lims->batch_id, 12141, 'batch id is 12141 for lane 1');
  is($lims->is_control, 0, 'lane 1 is not control');
  is($lims->is_pool, 1, 'lane 1 is pool');
  is($lims->library_id, 2988920, 'lib id');
  is($lims->library_name, '297p11', 'pool lib name');
  is($lims->contains_nonconsented_human, 0, 'does not contain nonconsented human');
  is($lims->contains_unconsented_human, 0, 'does not contain unconsented human (back compat)');
  is($lims->contains_nonconsented_xahuman, 0, 'does not contain nonconsented X and autosomal human');
  is($lims->tag_sequence, undef, 'tag_sequence undefined');
  is(scalar keys %{$lims->tags}, 13, '13 tags defined');
  is($lims->spiked_phix_tag_index, 168, 'spiked phix tag index');
  is(scalar $lims->descendants, 13, '13 descendant lims');
  is(scalar $lims->children, 13, '13 child lims');
  is($lims->to_string, 'st::api::lims object, driver - xml, batch_id 12141, id_run 6551, position 1, tag_index 0', 'object as string');
  is(join(q[,], $lims->library_names), join(q[,], sort @libs_6551_1), 'tag 0 library_names list');
  is(join(q[,], $lims->sample_names), join(q[,], sort @samples_6551_1), 'tag 0 sample_names list');
  is(join(q[,], $lims->sample_accession_numbers), join(q[,], sort @accessions_6551_1), 'tag 0 sample_accession_numbers list');
  is(join(q[,], $lims->study_names), join(q[,], sort @studies_6551_1), 'tag 0 study_names list');

  my $with_spiked_phix = 1;
  is(join(q[,], $lims->library_names($with_spiked_phix)), join(q[,], sort @libs_6551_1), 'tag 0 library_names list $with_spiked_phix = 1');
  is(join(q[,], $lims->sample_names($with_spiked_phix)), join(q[,], sort @samples_6551_1), 'tag 0 sample_names list $with_spiked_phix = 1');
  is(join(q[,], $lims->sample_accession_numbers($with_spiked_phix)), join(q[,], sort @accessions_6551_1), 'tag 0 sample_accession_numbers list $with_spiked_phix = 1');
  is(join(q[,], $lims->study_names($with_spiked_phix)), join(q[,], sort @studies_6551_1), 'tag 0 study_names list $with_spiked_phix = 1');

  $with_spiked_phix = 0;
  my @libs = @libs_6551_1; shift @libs;
  my @samples = @samples_6551_1; shift @samples;
  my @studies = @studies_6551_1; shift @studies;
  is(join(q[,], $lims->library_names($with_spiked_phix)), join(q[,], sort @libs), 'tag 0 library_names list $with_spiked_phix = 0;');
  is(join(q[,], $lims->sample_names($with_spiked_phix)), join(q[,], sort @samples), 'tag 0 sample_names list $with_spiked_phix = 0;');
  is(join(q[,], $lims->sample_accession_numbers($with_spiked_phix)), join(q[,], sort @accessions_6551_1), 'tag 0 sample_accession_numbers list $with_spiked_phix = 0');
  is(join(q[,], $lims->study_names($with_spiked_phix)), join(q[,], sort @studies), 'tag 0 study_names list $with_spiked_phix = 0;');
};

subtest 'Object for spiked phix tag' => sub {
  plan tests => 24;

  my $lims = st::api::lims->new(id_run => 6551, position => 1, tag_index => 168);
  is($lims->is_control, 1, 'tag 1/168 is control');
  is($lims->is_pool, 0, 'tag 1/168 is not a pool');
  is($lims->contains_nonconsented_human, 0, 'does not contain nonconcented human');
  is($lims->contains_nonconsented_xahuman, 0, 'does not contain nonconsented X and autosomal human');
  my $lib_id = 2389196;
  is($lims->library_id, $lib_id, 'hyb buffer lib id');
  my $lib_name = 'PhiX06Apr11';
  is($lims->library_name, $lib_name, 'hyb buffer lib name');
  my $sample_id = 1255141;
  is($lims->sample_id, $sample_id, 'hyb buffer sample id');
  my $study_id = 198;
  is($lims->study_id, $study_id, 'hyb buffer study id');
  is($lims->reference_genome, undef, 'reference genome not set');
  is($lims->tag_sequence, 'ACAACGCAAT', 'tag_sequence for phix');
  is($lims->tags, undef, 'tags undefined');
  is($lims->seq_qc_state, undef, 'no seq qc state');
  is($lims->spiked_phix_tag_index, 168, 'spiked phix tag index returned');
  is(scalar $lims->associated_lims, 0, 'no associated lims');
  is(scalar $lims->descendants, 0, 'no descendant lims');
  is(scalar $lims->associated_child_lims, 0, 'no associated child lims');
  is(scalar $lims->children, 0, 'no child lims');
  is(join(q[ ], $lims->library_names), $libs_6551_1[0], 'tag 168 library_names list');
  is(join(q[ ], $lims->sample_names), $samples_6551_1[0], 'tag 168 sample_names list');
  is(join(q[ ], $lims->sample_accession_numbers), q[], 'tag 168 sample_accession_numbers list (no accession for phiX)');
  is(join(q[ ], $lims->study_names), $studies_6551_1[0], 'tag 168 study_names list');

  my $with_spiked_phix = 0;
  is(join(q[ ], $lims->library_names($with_spiked_phix)), $libs_6551_1[0], 'tag 168 library_names list');
  is(join(q[ ], $lims->sample_names($with_spiked_phix)), $samples_6551_1[0], 'tag 168 sample_names list');
  is(join(q[ ], $lims->study_names($with_spiked_phix)), $studies_6551_1[0], 'tag 168 study_names list');
};

subtest 'Object for a tag' => sub {
  plan tests => 33;

  my $lims = st::api::lims->new(id_run => 6551, position => 1, tag_index => 1);
  is($lims->is_control, 0, 'tag 1/1 is not control');
  is($lims->is_pool, 0, 'tag 1/1 is not a pool');
  is($lims->contains_nonconsented_human, 0, 'does not contain nonconcented human');
  is($lims->contains_nonconsented_xahuman, 0, 'does not contain nonconsented X and autosomal human');
  is($lims->spiked_phix_tag_index, 168, 'spiked phix tag index returned');
  is(join(q[ ], $lims->library_names), 'SS109305 2798523', 'tag 1 library_names list');
  is(join(q[ ], $lims->sample_names), 'SS109305', 'tag 1 sample_names list');
  is(join(q[ ], $lims->sample_accession_numbers), 'ERS024591', 'tag 1 sample_accession_numbers list');
  is(join(q[ ], $lims->study_names), $studies_6551_1[1], 'tag 1 study_names list');

  my $with_spiked_phix = 0;
  is(join(q[ ], $lims->library_names($with_spiked_phix)), 'SS109305 2798523', 'tag 1 library_names list $with_spiked_phix = 0');
  is(join(q[ ], $lims->sample_names($with_spiked_phix)), 'SS109305', 'tag 1 sample_names list $with_spiked_phix = 0');
  is(join(q[ ], $lims->sample_accession_numbers($with_spiked_phix)), 'ERS024591', 'tag 1 sample_accession_numbers list $with_spiked_phix = 0');
  is(join(q[ ], $lims->study_names($with_spiked_phix)), $studies_6551_1[1], 'tag 1 study_names list $with_spiked_phix = 0');

  $lims = st::api::lims->new(id_run => 6607, position => 5, tag_index => 1);
  my $lims_nofb = st::api::lims->new(id_run => 6607, position => 5, tag_index => 1);
  is($lims->batch_id, 12378, 'batch id for lane 5 tag 1');
  is($lims->tag_index, 1, 'tag index 1');
  is($lims->is_control, 0, 'plex 5/1 is not control');
  is($lims->is_pool, 0, 'plex 5/1 is not pool');
  is($lims->library_id, 3111679, 'lib id');
  is($lims->sample_id, 1132331, 'sample id');
  is($lims->study_id, 429, 'study id'); # fallback
  my $project_id = 429;
  is($lims_nofb->study_id, $project_id, 'study id'); # no fallback
  is($lims->project_id, $project_id, 'project id');
  is($lims->request_id, undef, 'request id');
  is($lims->library_name, 'HiC_H_ON_DCJ 3111679', 'lib name');
  is($lims->sample_name, 'HiC_H_ON_DCJ', 'sample name undefined');
  is($lims->study_name, '3C and HiC of Plasmodium falciparum IT', 'study name');
  my $project_name = q[3C and HiC of Plasmodium falciparum IT];
  is($lims->project_name, $project_name, 'project name');
  is($lims->tag_sequence, 'ATCACGTT', 'tag_sequence');
  is($lims->tags, undef, 'tags undefined');
  is($lims->spiked_phix_tag_index, undef, 'spiked phix tag index undefined');
  ok(!$lims->alignments_in_bam, 'no bam alignment');
  is($lims->seq_qc_state, undef, 'no seq qc state');
  is(scalar $lims->associated_lims, 0, 'no associated lims');
};

subtest 'Object for a non-pool lane' => sub {
  plan tests => 96;

  my $lims = st::api::lims->new(id_run => 6607, position => 1);
  isa_ok($lims, 'st::api::lims');
  is($lims->batch_id, 12378, 'batch id for lane 1');
  is($lims->is_control, 0, 'lane 1 is not control');
  is($lims->is_pool, 0, 'lane 1 is not pool');
  is($lims->library_id, 3033734, 'lib id');
  is($lims->sample_id, 1121926, 'sample id');
  is($lims->study_id, 1811, 'study id');
  is($lims->project_id, 810, 'project id');
  is($lims->contains_nonconsented_human, 0, 'does not contain nonconcented human');
  is($lims->contains_nonconsented_xahuman, 0, 'does not contain nonconsented X and autosomal human');
  is($lims->request_id, 3156170, 'request id');
  is($lims->library_name, 'BS_3hrsomuleSm_202790 3033734', 'lib name');
  is($lims->sample_name, 'BS_3hrsomuleSm_202790', 'sample name');
  is($lims->study_name, 'Schistosoma mansoni methylome', 'study name');
  is($lims->project_name, 'Schistosoma mansoni methylome', 'project name');
  is($lims->tag_sequence, undef, 'tag_sequence undefined');
  is($lims->tags, undef, 'tags undefined');
  is($lims->spiked_phix_tag_index, undef, 'spiked phix tag index undefined');
  is($lims->tag_sequence, undef, 'tag_sequence undefined');
  is($lims->seq_qc_state, undef, 'seq qc not set');
  is(scalar $lims->associated_lims, 0, 'no associated lims');

  my @methods;
  lives_ok {@methods = $lims->method_list} 'list of attributes generated';
  foreach my $method (@methods) {
    lives_ok {$lims->$method} qq[invoking method or attribute $method does not throw an error];
  }

  is(join(q[ ], $lims->library_names), 'BS_3hrsomuleSm_202790 3033734', 'non-pool lane library_names list');
  is(join(q[ ], $lims->sample_names), 'BS_3hrsomuleSm_202790', 'non-pool lane sample_names list');
  is(join(q[ ], $lims->sample_accession_numbers), 'ERS028649', 'non-pool lane sample_accession_numbers list');
  is(join(q[ ], $lims->study_names), 'Schistosoma mansoni methylome', 'non-pool lane study_names list');
};

subtest 'Priority and seqqc state' => sub {
  plan tests => 8;

  my $lims = st::api::lims->new(id_run => 6607, position => 2); # non-pool lane
  is($lims->seq_qc_state, undef, 'seq qc not set for pending');
  is($lims->lane_priority, 0, 'priority 0');
  $lims = st::api::lims->new(id_run => 6607, position => 3);
  is($lims->seq_qc_state, 1, 'seq qc 1 for pass');
  is($lims->lane_priority, 1, 'priority 1');
  $lims = st::api::lims->new(id_run => 6607, position => 4);
  is($lims->seq_qc_state, 0, 'seq qc 0 for fail');
  $lims = st::api::lims->new(id_run => 6607, position => 5);
  throws_ok {$lims->seq_qc_state} qr/Unexpected value 'some' for seq qc state/, 'error for unexpected qc state';
  $lims = st::api::lims->new(id_run => 6607, position => 5, tag_index => 1);
  is($lims->lane_priority, undef, 'priority undefined on plex level');
  $lims = st::api::lims->new(id_run => 6607);
  is($lims->lane_priority, undef, 'priority undefined on batch level');
};

subtest 'Object for a not spiked pool' => sub {
  plan tests => 26;

  my $lims = st::api::lims->new(id_run => 6607, position => 5);
  is($lims->batch_id, 12378, 'batch id for lane 5');
  is($lims->tag_index, undef, 'tag index undefined');
  is($lims->is_control, 0, 'lane 5 is not control');
  is($lims->is_pool, 1, 'lane 5 is pool');
  is($lims->library_id, 3111688, 'lib id');
  is($lims->sample_id, undef, 'sample id undefined');
  is($lims->study_id, 429, 'study id');
  is($lims->project_id, 429, 'project id');
  is($lims->request_id, 3259935, 'request id');
  is($lims->library_name, '3C_HiC_Pool3', 'lib name');
  is($lims->sample_name, undef, 'sample name undefined');
  is($lims->study_name, '3C and HiC of Plasmodium falciparum IT', 'study name');
  my $description = q[Illumina sequencing of chromatin conformation capture and its derivatives is being carried out to study nuclear architecture in antigenically selected lines of Plasmodium falciparum. This data is part of a pre-publication release. For information on the proper use of pre-publication data shared by the Wellcome Trust Sanger Institute (including details of any publication moratoria), please see http://www.sanger.ac.uk/datasharing/];
  is($lims->study_description, $description, 'study description');
  is($lims->project_name, '3C and HiC of Plasmodium falciparum IT', 'project name');
  my $expected_tags = {1=>'ATCACGTT', 2=>'CGATGTTT', 3=>'TTAGGCAT', 4=>'TGACCACT', 5=>'ACAGTGGT', 6=>'GCCAATGT', 7=>'CAGATCTG',
                       8 => 'ACTTGATG', 9=>'GATCAGCG',};
  is_deeply($lims->tags, $expected_tags, 'tags mapping');
  is($lims->spiked_phix_tag_index, undef, 'spiked phix tag index undefined');
  is($lims->tag_sequence, undef, 'tag_sequence undefined');
  is($lims->to_string, 'st::api::lims object, driver - xml, batch_id 12378, id_run 6607, position 5', 'object as string');

  my $libs = 'HIC_M_B15C2 3111683,HiC_H_Dd2 3111680,HiC_H_LT3D7 3111687,HiC_H_OFF_DCJ 3111682,HiC_H_ON_DCJ 3111679,HiC_H_PQP1 3111681,HiC_M_3D7 3111685,HiC_M_ER3D7 3111686,HiC_M_Rev1 3111684';
  my $samples = 'HIC_M_B15C2,HiC_H_Dd2,HiC_H_LT3D7,HiC_H_OFF_DCJ,HiC_H_ON_DCJ,HiC_H_PQP1,HiC_M_3D7,HiC_M_ER3D7,HiC_M_Rev1';
  my $accessions = 'ERS033158,ERS033160,ERS033162,ERS033168,ERS033170,ERS033172,ERS033174,ERS033176,ERS033178';
  my $study = '3C and HiC of Plasmodium falciparum IT';
  is(join(q[,], $lims->library_names), $libs, 'pooled not-spiked lane library_names list');
  is(join(q[,], $lims->sample_names), $samples, 'pooled not-spiked lane sample_names list');
  is(join(q[,], $lims->sample_accession_numbers), $accessions, 'pooled not-spiked lane sample_accession_numbers list');
  is(join(q[,], $lims->study_names), $study, 'pooled not-spiked lane study_names list');

  my $with_spiked_phix = 0;
  is(join(q[,], $lims->library_names($with_spiked_phix)), $libs, 'pooled not-spiked lane library_names list $with_spiked_phix = 0');
  is(join(q[,], $lims->sample_names($with_spiked_phix)), $samples, 'pooled not-spiked lane sample_names list $with_spiked_phix = 0');
  is(join(q[,], $lims->sample_accession_numbers($with_spiked_phix)), $accessions, 'pooled not-spiked lane sample_accession_numbers list $with_spiked_phix = 0');
  is(join(q[,], $lims->study_names($with_spiked_phix)), $study, 'pooled not-spiked lane study_names list $with_spiked_phix = 0');
};

{
  my $lims = st::api::lims->new(batch_id => 13410, position => 1);
  ok(!$lims->is_control, 'lane is not a control (despite having a control tag within its hyb buffer tag)');
}

subtest 'Library types' => sub {
  plan tests => 6;

  my $lims = st::api::lims->new(id_run => 6607);
  is($lims->library_type, undef, 'library type undefined on a batch level');
  $lims = st::api::lims->new(id_run => 6607, position => 2); # non-pool lane
  is($lims->library_type, 'Illumina cDNA protocol', 'library type');
  $lims = st::api::lims->new(id_run => 6607, position => 5);
  is($lims->library_type, undef, 'library type undefined for a pool');
  $lims = st::api::lims->new(id_run => 6607, position => 5, tag_index => 0);
  is($lims->library_type, undef, 'library type undefined for tag 0');
  $lims = st::api::lims->new(id_run => 6607, position => 5, tag_index => 1);
  is($lims->library_type, 'Custom', 'library type');
  $lims = st::api::lims->new(id_run => 6607, position => 6, tag_index => 8);
  is($lims->library_type, 'Standard', 'library type');
};

subtest 'Unconcented human and xahuman' => sub {
  plan tests => 11;

  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/npg_api';

  my $lims = st::api::lims->new(batch_id   => 1536,position => 5);
  ok(!$lims->is_pool, 'lane is not a pool');
  is($lims->contains_nonconsented_human, 1, 'contains nonconsented human');
  is($lims->contains_unconsented_human, 1, 'contains unconsented human (back compat)');

  $lims = st::api::lims->new(batch_id => 13861, position => 2);
  ok($lims->is_pool, 'lane is a pool');
  ok($lims->contains_nonconsented_human, 'pool contains unconsented human');

  $lims = st::api::lims->new(batch_id => 13861, position => 2, tag_index => 0);
  ok($lims->contains_nonconsented_human, 'tag 0 contains unconsented human');

 local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/st_api_lims_new';

  $lims = st::api::lims->new(id_run => 8260);
  is($lims->contains_nonconsented_xahuman, 0,
    'run does contain nonconsented X and autosomal human does not propagate to run level');

  $lims = st::api::lims->new(id_run => 8260, position => 2);
  is($lims->contains_nonconsented_xahuman, 0, 'lane 2 does not contain nonconsented X and autosomal human');
  $lims = st::api::lims->new(id_run => 8260, position => 8);
  is($lims->contains_nonconsented_xahuman, 1, 'lane 8 does contain nonconsented X and autosomal human');
  $lims = st::api::lims->new(id_run => 8260, position => 2, tag_index => 33);
  is($lims->contains_nonconsented_xahuman, 0, 'plex 33 lane 2 does not contain nonconsented X and autosomal human');
  $lims = st::api::lims->new(id_run => 8260, position => 8, tag_index => 57);
  is($lims->contains_nonconsented_xahuman, 1, 'plex 57 lane 8 does contain nonconsented X and autosomal human');
};

subtest 'Bait name' => sub {
  plan tests => 11;

  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/npg_api';
  my $lims = st::api::lims->new(batch_id   => 16442);
  is($lims->bait_name, undef, 'bait name undefined on a batch level');
  $lims = st::api::lims->new(batch_id   => 16442, position => 1);
  is($lims->bait_name, undef, 'bait name undefined on a pool level');
  $lims = st::api::lims->new(batch_id   => 16442, position => 1, tag_index=> 2);
  is($lims->bait_name,'Human all exon 50MB', 'bait name for a plex');
  $lims = st::api::lims->new(batch_id   => 16442, position => 1, tag_index=> 3);
  is($lims->bait_name,'Fox bait', 'bait name for another plex');
  $lims = st::api::lims->new(batch_id   => 16442, position => 8, tag_index=> 5);
  is($lims->bait_name,'Mouse some exon', 'bait name for yet another plex');
  $lims = st::api::lims->new(batch_id   => 16442, position => 1, tag_index=> 4);
  is($lims->bait_name, undef, 'bait name undefined if no bait element');
  $lims = st::api::lims->new(batch_id   => 16442, position => 1, tag_index=> 5);
  is($lims->bait_name, undef, 'bait name undefined if no bait name tag is empty');
  $lims = st::api::lims->new(batch_id   => 16442, position => 1, tag_index=> 168);
  is($lims->bait_name, undef, 'bait name undefined for hyp buffer');

  $lims = st::api::lims->new(batch_id   => 3022, position => 1);
  is($lims->bait_name,'Mouse all exon', 'bait name for a non-pool lane');
  $lims = st::api::lims->new(batch_id   => 3022, position => 2);
  is($lims->bait_name, undef, 'bait name undefined for a non-pool lane if there is no bait element');
  $lims = st::api::lims->new(batch_id   => 3022, position => 4);
  is($lims->bait_name, undef, 'bait name undefined for a control lane despite the presence of the bait element');
};

subtest 'Study attributes' => sub {
  plan tests => 11;

  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/st_api_lims_new';

  my $lims = st::api::lims->new(batch_id=>17763, position=>1,tag_index=>1);
  is( $lims->study_title(), 'hifi test', q{study title} );
  is( $lims->study_name(), 'Kapa HiFi test', 'study name');
  is( $lims->study_accession_number(), undef, q{no study accession obtained} );
  is( $lims->study_publishable_name(), q{hifi test}, q{study title returned as publishable name} );

  $lims = st::api::lims->new(batch_id=>17763, position=>1,tag_index=>2);
  ok(! $lims->alignments_in_bam, 'no alignments in BAM when false in corresponding XML in study');
  is( $lims->study_title(), 'Genetic variation in Kuusamo', q{study title obtained} );
  is( $lims->study_accession_number(), 'EGAS00001000020', q{study accession obtained} );
  is( $lims->study_publishable_name(), 'EGAS00001000020', q{accession returned as study publishable name} );
  is( $lims->sample_publishable_name(), q{ERS003242}, q{sample publishable name returns accession} );
  ok(! $lims->separate_y_chromosome_data, 'do not separate y chromosome data');

  $lims = st::api::lims->new(batch_id => 22061, position =>1, tag_index=>66);
  ok($lims->separate_y_chromosome_data, 'separate y chromosome data');
};

subtest 'Tag sequence and library type from sample description' => sub {
  plan tests => 15;

  my $sample_description =  'AB GO (grandmother) of the MGH meiotic cross. The same DNA was split into three aliquots (of which this';
  is(st::api::lims::_tag_sequence_from_sample_description($sample_description), undef, q{tag undefined for a description containing characters in round brackets} );
  $sample_description = "3' end enriched mRNA from morphologically abnormal embryos from dag1 knockout incross 3. A 6 base indexing sequence (GTAGAC) is bases 5 to 11 of read 1 followed by polyT.  More information describing the mutant phenotype can be found at the Wellcome Trust Sanger Institute Zebrafish Mutation Project website http://www.sanger.ac.uk/cgi-bin/Projects/D_rerio/zmp/search.pl?q=zmp_phD";
  is(st::api::lims::_tag_sequence_from_sample_description($sample_description), q{GTAGAC}, q{correct tag from a complex description} );
  $sample_description = "^M";
  is(st::api::lims::_tag_sequence_from_sample_description($sample_description), undef, q{tag undefined for a description with carriage return} );

  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/tag_from_sample_description';
  #diag q[Tests for deducing tags from batch 19158 (associated with run 3905 by hand)]; 
  my $lims8 = st::api::lims->new(batch_id => 19158, position => 8);
  my @alims8 = $lims8->associated_lims;
  is(scalar @alims8, 7, 'Found 7 plexes in position 8');

  my @tags = $lims8->tags();
  is(scalar @tags, 1, 'Found 1 tags array');

  cmp_ok($tags[0]->{5}, q(ne), q(ACAGTGGT), 'Do not use expected_sequence sequence for tag');
  cmp_ok($tags[0]->{5}, q(eq), q(GTAGAC), 'Use sample_description sequence for tag');

  my $lims1 = st::api::lims->new(batch_id => 19158, position => 1);
  my @alims1 = $lims1->associated_lims;
  is(scalar @alims1, 6, 'Found 6 plexes in position 1');

  my @tags1 = $lims1->tags();
  is(scalar @tags1, 1, 'Found 1 tags array');

  cmp_ok($tags1[0]->{144}, q(eq), q(CCTGAGCA), 'Use expected_sequence sequence for tag');

  my $lims85 = st::api::lims->new(batch_id => 19158, position => 8, tag_index => 5);
  is($lims85->library_type, '3 prime poly-A pulldown', 'library type');
  is($lims85->tag_sequence, 'GTAGAC', 'plex tag sequence from sample description');
  ok($lims85->sample_description =~ /end enriched mRNA/sm, 'sample description available');

  my $lims1144 = st::api::lims->new(batch_id => 19158, position => 1, tag_index => 144);
  isnt($lims1144->library_type, '3 prime poly-A pulldown', 'library type');
  is($lims1144->tag_sequence, 'CCTGAGCA', 'plex tag sequence directly from batch xml');
};

subtest 'Inline index' => sub {
  plan tests => 14;

  my $lims = st::api::lims->new(id_run=>10638, position=>5);
  is ($lims->id_run(), 10638, "Found the run");
  my @children = $lims->children();
  isnt (scalar @children, 0, "We have children");
  is($lims->inline_index_exists,1,'Found an inline index');
  is($lims->inline_index_start,7,'found correct inline index start');
  is($lims->inline_index_end,12,'found correct inline index end');
  is($lims->inline_index_read,2,'found correct inline index read');
  is($lims->tag_sequence,undef,'tag sequence undefined for lane level');

  $lims = st::api::lims->new(id_run=>10638, position=>6);
  is ($lims->id_run(), 10638, "Found the run");
  @children = $lims->children();
  isnt (scalar @children, 0, "We have children");
  is($lims->inline_index_exists,1,'Found an inline index');
  is($lims->inline_index_start,6,'found correct inline index start');
  is($lims->inline_index_end,10,'found correct inline index end');
  is($lims->inline_index_read,1,'found correct inline index read');
  is($lims->tag_sequence,undef,'tag sequence undefined for lane level');
};

subtest 'Run-level object via samplesheet driver' => sub {
  plan tests => 36;

  my $path = 't/data/samplesheet/miseq_default.csv';

  my $ss = st::api::lims->new(id_run => 10262,  path => $path, driver_type => 'samplesheet');
  isa_ok ($ss->driver, 'st::api::lims::samplesheet', 'samplesheet driver object instantiated');  
  my @lanes;
  lives_ok {@lanes = $ss->children}  'can get lane-level objects';
  is ($lanes[0]->id_run, 10262, 'lane id_run as set');

  $ss = st::api::lims->new(id_run => 10000,  path => $path, driver_type => 'samplesheet');
  is ($ss->id_run, 10000, 'id_run as set');
  warning_is {@lanes = $ss->children} 
    q[Supplied id_run 10000 does not match Experiment Name, 10262],
    'can get lane-level objects, get warned about id_run mismatch';
  is ($lanes[0]->id_run, 10000, 'lane id_run as set, differs from Experiment Name');

  $ss = st::api::lims->new(path => $path, driver_type => 'samplesheet');
  is ($ss->is_pool, 0, 'is_pool false on run level');
  is ($ss->is_control, undef, 'is_control undef on run level');
  is ($ss->library_id, undef, 'library_id undef on run level');
  is ($ss->library_name, undef, 'library_name undef on run level');
  is ($ss->id_run, undef, 'id_run undefined');
  warning_is {@lanes = $ss->children}
    q[id_run is set to Experiment Name, 10262],
    'can get lane-level objects, get warning about setting id_run from Experiment Name';
  is (scalar @lanes, 1, 'one lane returned');
  my $lane = $lanes[0];
  is ($lane->position, 1, 'position is 1');
  is ($lane->id_run, 10262, 'lane id_run set correctly from Experiment Name');
  is ($lane->is_pool, 1, 'is_pool true on lane level');
  is ($lane->is_control, undef, 'not a control lane');
  is ($lane->library_id, undef, 'library_id indefined for a pool');
  my @plexes;
  lives_ok {@plexes = $lane->children}  'can get plex-level objects';
  is (scalar @plexes, 96, '96 plexes returned');
  is ($plexes[0]->position, 1, 'position of the first plex is 1');
  is ($plexes[0]->tag_index, 1, 'tag_index of the first plex is 1');
  is ($plexes[0]->id_run, 10262, 'id_run of the first plexe set correctly from Experiment Name');
  is ($plexes[0]->library_id, 7583411, 'library_id of the first plex');
  is ($plexes[0]->sample_name, 'LIA_1', 'sample_name of the first plex');
  is ($plexes[0]->sample_id, undef, 'sample_id of the first plex in undefined');
  is ($plexes[0]->is_pool, 0, 'is_pool false on plex level');
  is ($plexes[0]->is_control, undef, 'is_control false on for a plex');
  is ($plexes[0]->default_tag_sequence, 'ATCACGTT', 'default tag sequence of the first plex');
  is ($plexes[0]->tag_sequence, 'ATCACGTT', 'tag sequence of the first plex');
  is ($plexes[95]->position, 1, 'position of the last plex is 1');
  is ($plexes[95]->tag_index, 96, 'tag_index of the last plex is 96');
  is ($plexes[95]->id_run, 10262, 'id_run of the last plex set correctly from Experiment Name');
  is ($plexes[95]->tag_sequence, 'GTCTTGGC', 'tag sequence of the last plex');
  is ($plexes[95]->library_id, 7583506, 'library_id of the last plex');
  is ($plexes[95]->sample_name, 'LIA_96', 'sample_name of the last plex');
};

subtest 'Lane-level object via samplesheet driver' => sub {
  plan tests => 16;

  my $path = 't/data/samplesheet/miseq_default.csv';
  lives_ok {st::api::lims->new(id_run => 10262, position =>2, path => $path, driver_type => 'samplesheet')}
    'no error instantiation an object for a non-existing lane';
  throws_ok {st::api::lims->new(id_run => 10262, position =>2, path => $path, driver_type => 'samplesheet')->library_id}
    qr/Position 2 not defined in/, 'error invoking a driver method on an object for a non-existing lane';

  lives_ok {st::api::lims->new(id_run => 10262, position =>2, driver_type => 'samplesheet')}
    'no error instantiation an object without path';

  throws_ok {st::api::lims->new(id_run => 10262, position =>2, driver_type => 'samplesheet')->library_id}
    qr/Attribute \(path\) does not pass the type constraint/, 'error invoking a driver method on an object with path undefined'; # NPG_CACHED_SAMPLESHEET_FILE is unset

  my $nopath = join q[/], tempdir( CLEANUP => 1 ), 'xxx';
  throws_ok {st::api::lims->new(id_run => 10262, path => $nopath, position =>2, driver_type => 'samplesheet')->library_id}
    qr/Validation failed for 'NpgTrackingReadableFile'/, 'error invoking a driver method on an object with non-existing path';

  {
    local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = $path;

    my $ss=st::api::lims->new(id_run => 10262, position =>1, driver_type => 'samplesheet');
    is ($ss->path, $path, 'samplesheet path captured from NPG_CACHED_SAMPLESHEET_FILE') or diag explain $ss;
    is ($ss->position, 1, 'correct position');
    is ($ss->is_pool, 1, 'lane is a pool');
    is ($ss->library_id, undef, 'pool lane library_id undefined');
    is (scalar $ss->children, 96, '96 plexes returned');
  }

  my $ss=st::api::lims->new(id_run => 10262, position =>1, tag_index => 0, path => $path, driver_type => 'samplesheet');
  is (scalar $ss->children, 96, '96 children returned for tag zero');
  is ($ss->is_pool, 1, 'tag zero is a pool');
  is ($ss->library_id, undef, 'tag_zero library_id undefined');
  is ($ss->default_tag_sequence, undef, 'default tag sequence undefined');
  is ($ss->tag_sequence, undef, 'tag sequence undefined');
  is ($ss->purpose, undef, 'purpose');
};

subtest 'Plex-level object via samplesheet driver' => sub {
  plan tests => 10;

  my $path = 't/data/samplesheet/miseq_default.csv';
  lives_ok {st::api::lims->new(id_run => 10262, position =>1, tag_index=>999,path => $path, driver_type => 'samplesheet')}
    'no error instantiation an object for a non-existing tag_index';
  throws_ok {st::api::lims->new(id_run => 10262, position =>1, tag_index => 999, path => $path, driver_type => 'samplesheet')->children}
    qr/Tag index 999 not defined in/, 'error invoking a driver method on an object for a non-existing tag_index';

  my $ss=st::api::lims->new(id_run => 10262, position =>1, tag_index => 3, path => $path, driver_type => 'samplesheet');
  is ($ss->position, 1, 'correct position');
  is ($ss->tag_index, 3, 'correct tag_index');
  is ($ss->is_pool, 0, 'plex is not a pool');
  is ($ss->default_tag_sequence, 'TTAGGCAT', 'correct default tag sequence');
  is ($ss->tag_sequence, $ss->default_tag_sequence, 'tag sequence is the same as default tag sequence');
  is ($ss->library_id, 7583413, 'library id is correct');
  is ($ss->sample_name, 'LIA_3', 'sample name is correct');
  is (scalar $ss->children, 0, 'zero children returned');
};

subtest 'Samplesheet driver for a composition' => sub {
  plan tests => 28;

  my $path = 't/data/samplesheet/miseq_default.csv';
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = $path;

  my $ss;
  lives_ok { $ss = st::api::lims->new(rpt_list => '10262:1:3;2:3:4', path => $path) }
    'no error instantiation an object for a composition';
  throws_ok { $ss->children }
    qr/Cannot use samplesheet driver with components from multiple runs/,
   'error when components belong to different runs';

  $ss=st::api::lims->new(rpt_list => '10262:1:3', driver_type => 'samplesheet');
  is ($ss->driver, undef, 'driver undefined');
  is ($ss->path, undef, 'samplesheet path is undefined');
  is ($ss->rpt_list, '10262:1:3', 'rpt list as given');
  is ($ss->id_run, undef, 'run id undefined');
  is ($ss->position, undef, 'position undefined');
  is ($ss->tag_index, undef, 'tag_index undefined');
  ok (!$ss->is_pool, 'not a pool');
  is ($ss->is_composition, 1, 'this is a composition');
  is (scalar $ss->num_children, 1, 'one child');
  is ($ss->default_tag_sequence, 'TTAGGCAT', 'correct default tag sequence');
  is ($ss->tag_sequence, undef, 'tag sequence is undefined');
  is ($ss->library_id, 7583413, 'library id is correct');
  is ($ss->sample_name, 'LIA_3', 'sample name is correct');
  $ss = ($ss->children)[0];
  ok ($ss->driver && (ref $ss->driver eq 'st::api::lims::samplesheet'), 'correct driver');
  is ($ss->driver_type, 'samplesheet', 'driver type is samplesheet');
  is ($ss->rpt_list, undef, 'rpt list is undefined');
  is ($ss->id_run, 10262, 'correct run id');
  is ($ss->position, 1, 'correct position');
  is ($ss->tag_index, 3, 'correct tag_index');
  ok (!$ss->is_pool, 'plex is not a pool');
  is ($ss->is_composition, 0, 'not a composition');
  is ($ss->default_tag_sequence, 'TTAGGCAT', 'correct default tag sequence');
  is ($ss->tag_sequence, $ss->default_tag_sequence, 'tag sequence is the same as default tag sequence');
  is ($ss->library_id, 7583413, 'library id is correct');
  is ($ss->sample_name, 'LIA_3', 'sample name is correct');
  is (scalar $ss->children, 0, 'zero children returned');
};

subtest 'Instantiating a samplesheet driver' => sub {
  plan tests => 15;

  my $ss_path = 't/data/samplesheet/miseq_default.csv';
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = $ss_path;
  my $l;
  lives_ok {$l = st::api::lims->new(id_run => 10262,)}
    'no error creating an object with samplesheet file defined in env var';
  is ($l->driver_type, 'samplesheet', 'driver type is built as samplesheet');
  is ($l->path, $ss_path, 'correct path is built');
  is (ref $l->driver, 'st::api::lims::samplesheet', 'correct driver object type');
  is ($l->driver->path, $ss_path, 'correct path assigned to the driver object');

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/samplesheet';
  lives_ok {$l = st::api::lims->new(id_run => 10262,)}
    'no error creating an object with samplesheet file defined in env var';
  is ($l->driver_type, 'samplesheet', 'driver type is samplesheet');
  ok ($l->path, 'path is built');
  throws_ok {$l->children}
    qr/Is a directory/,
    'directory given as a samplesheet file path - error';

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/samplesheet/non-existing';
  lives_ok {$l = st::api::lims->new(id_run => 10262,)}
    'no error creating an object with samplesheet file defined in env var';
  is ($l->driver_type, 'samplesheet', 'driver type is samplesheet');
  throws_ok {$l->children}
    qr/Attribute \(path\) does not pass the type constraint/,
    'directory given as a samplesheet file path - error';

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/samplesheet/non-existing';
  lives_ok {$l = st::api::lims->new(id_run => 10262, path => $ss_path)}
    'no error creating an object with samplesheet file defined in env var and path given';
  is ($l->driver_type, 'samplesheet', 'driver type is samplesheet');
  lives_ok {$l->children} 'given path takes precedence';
};

subtest 'Dual index' => sub {
  plan tests => 32;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/samplesheet/dual_index_extended.csv';
  _test_di( st::api::lims->new(id_run => 6946) );

  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/samplesheet';
  _test_di( st::api::lims->new(batch_id => 1) );
};

sub _test_di {
  my $l = shift;

  my @lanes = $l->children;
  is (scalar @lanes, 2, 'two lanes');
  my @plexes = $lanes[0]->children;
  is (scalar @plexes, 3, 'three samples in lane 1');
  my $plex = $plexes[0];
  is($plex->default_tag_sequence, 'CGATGTTT', 'first index');
  is($plex->default_tagtwo_sequence, 'AAAAAAAA', 'second index');
  is($plex->tag_sequence, 'CGATGTTTAAAAAAAA', 'combined tag sequence');
  $plex = $plexes[2];
  is($plex->default_tag_sequence, 'TGACCACT', 'first index');
  is($plex->default_tagtwo_sequence, 'AAAAAAAA', 'second index');
  is($plex->tag_sequence, 'TGACCACTAAAAAAAA', 'combined tag sequence');
  @plexes = $lanes[1]->children;
  is (scalar @plexes, 3, 'three samples in lane 2');
  $plex = $plexes[0];
  is($plex->default_tag_sequence, 'GCTAACTC', 'first index');
  is($plex->default_tagtwo_sequence, 'GGGGGGGG', 'second index');
  is($plex->tag_sequence, 'GCTAACTCGGGGGGGG', 'combined tag sequence');
  $plex = $plexes[2];
  is($plex->default_tag_sequence, 'GTCTTGGC', 'first index');
  is($plex->default_tagtwo_sequence, 'GGGGGGGG', 'second index');
  is($plex->tag_sequence, 'GTCTTGGCGGGGGGGG', 'combined tag sequence');
  is($plex->purpose, 'standard', 'purpose');
}

1;
