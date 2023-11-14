use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;

use_ok('st::api::lims');

subtest 'Aggregation across lanes for pools' => sub {
  plan tests => 85;
  
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/test40_lims/samplesheet_novaseq4lanes.csv';

  my $l = st::api::lims->new(rpt_list => '25846:1:3');
  throws_ok { $l->aggregate_xlanes() } qr/Not run-level object/,
    'method cannot be run for a composition';
  $l = st::api::lims->new(id_run => 25846, position => 1);
  throws_ok { $l->aggregate_xlanes() } qr/Not run-level object/,
    'method cannot be run for a lane-level object';
  $l = st::api::lims->new(id_run => 25846, position => 1, tag_index => 4);
  throws_ok { $l->aggregate_xlanes() } qr/Not run-level object/,
    'method cannot be run for a plex-level object';

  $l = st::api::lims->new(id_run => 25846);
  
  throws_ok { $l->aggregate_xlanes(qw/2 10/) }
    qr/Requested position 10 does not exists in /,
    'error if requested position does not exist';

  my @merged = $l->aggregate_xlanes();
  is (scalar @merged, 23, 'number of aggregates is number of tags plus two');
  my $tag_zero = pop @merged;
  my $tag_spiked = pop @merged;
  my $tag_last = pop @merged;
  my $tag_first = shift @merged;
  is ($tag_zero->rpt_list, '25846:1:0;25846:2:0;25846:3:0;25846:4:0',
    'rpt list for tag zero object');
  is ($tag_spiked->rpt_list, '25846:1:888;25846:2:888;25846:3:888;25846:4:888',
    'rpt list for spiked in tag object');
  is ($tag_last->rpt_list, '25846:1:21;25846:2:21;25846:3:21;25846:4:21',
    'rpt list for tag 21 object');
  is ($tag_first->rpt_list, '25846:1:1;25846:2:1;25846:3:1;25846:4:1',
    'rpt list for tag 1 object');

  @merged = $l->aggregate_xlanes(qw/1 4/);
  is (scalar @merged, 23, 'number of aggregates is number of tags plus two');
  $tag_zero = pop @merged;
  $tag_spiked = pop @merged;
  $tag_last = pop @merged;
  $tag_first = shift @merged;
  is ($tag_zero->rpt_list, '25846:1:0;25846:4:0',
    'rpt list for tag zero object');
  is ($tag_spiked->rpt_list, '25846:1:888;25846:4:888',
    'rpt list for spiked in tag object');
  is ($tag_last->rpt_list, '25846:1:21;25846:4:21',
    'rpt list for tag 21 object');
  is ($tag_first->rpt_list, '25846:1:1;25846:4:1',
    'rpt list for tag 1 object');

  @merged = $l->aggregate_xlanes(qw/1/);
  is (scalar @merged, 23, 'number of aggregates is number of tags plus two');
  $tag_zero = pop @merged;
  $tag_spiked = pop @merged;
  $tag_last = pop @merged;
  $tag_first = shift @merged;
  is ($tag_zero->rpt_list, '25846:1:0', 'rpt list for tag zero object');
  is ($tag_spiked->rpt_list, '25846:1:888', 'rpt list for spiked in tag object');
  is ($tag_last->rpt_list, '25846:1:21', 'rpt list for tag 21 object');
  is ($tag_first->rpt_list, '25846:1:1', 'rpt list for tag 1 object');

  @merged = $l->aggregate_xlanes();
  is (scalar @merged, 23, 'number of aggregates is number of tags plus two');
  $tag_zero = pop @merged;
  $tag_spiked = pop @merged;
  $tag_last = pop @merged;
  $tag_first = shift @merged;
  is ($tag_zero->rpt_list, '25846:1:0;25846:2:0;25846:3:0;25846:4:0',
    'rpt list for tag zero object');
  is ($tag_spiked->rpt_list, '25846:1:888;25846:2:888;25846:3:888;25846:4:888',
    'rpt list for spiked in tag object');
  is ($tag_last->rpt_list, '25846:1:21;25846:2:21;25846:3:21;25846:4:21',
    'rpt list for tag 21 object');
  is ($tag_first->rpt_list, '25846:1:1;25846:2:1;25846:3:1;25846:4:1',
    'rpt list for tag 1 object');

  my $expected = {
    '25846:1:0;25846:2:0;25846:3:0;25846:4:0' => {
      'sample_id' => undef,
      'sample_name' => undef,
      'sample_common_name' => 'Homo sapiens',
      'study_id' => 5318,
      'study_name' => 'NovaSeq testing',
      'reference_genome' => 'Homo_sapiens (1000Genomes_hs37d5 + ensembl_75_transcriptome)',
      'library_id' => undef,
      'library_name' => undef,
      'library_type' => 'Standard',
      'default_tag_sequence' => undef,
      'study_alignments_in_bam' => 1,
      'study_contains_nonconsented_human' => 0
    },
    '25846:1:888;25846:2:888;25846:3:888;25846:4:888' => {
      'sample_id' => '1255141',
      'sample_name' => 'phiX_for_spiked_buffers',
      'sample_common_name' => undef,
      'study_id' => 198,
      'study_name' => 'Illumina Controls',
      'reference_genome' => undef,
      'library_id' => '17883061',
      'library_name' => '17883061',
      'library_type' => undef,
      'default_tag_sequence' => 'ACAACGCAATC',
      'study_alignments_in_bam' => 1,
      'study_contains_nonconsented_human' => 0
    },
    '25846:1:21;25846:2:21;25846:3:21;25846:4:21' => {
      'sample_id' => '3681772',
      'sample_name' => '5318STDY7462477',
      'sample_common_name' => 'Homo sapiens',
      'study_id' => 5318,
      'study_name' => 'NovaSeq testing',
      'reference_genome' => 'Homo_sapiens (1000Genomes_hs37d5 + ensembl_75_transcriptome)',
      'library_id' => '21059089',
      'library_name' => '21059089',
      'library_type' => 'Standard',
      'default_tag_sequence' => 'TCGAGCGT',
      'study_alignments_in_bam' => 1,
      'study_contains_nonconsented_human' => 0
    },
    '25846:1:1;25846:2:1;25846:3:1;25846:4:1' => {
      'sample_id' => '3681752',
      'sample_name' => '5318STDY7462457',
      'sample_common_name' => 'Homo sapiens',
      'study_id' => 5318,
      'study_name' => 'NovaSeq testing',
      'reference_genome' => 'Homo_sapiens (1000Genomes_hs37d5 + ensembl_75_transcriptome)',
      'library_id' => '21059039',
      'library_name' => '21059039',
      'library_type' => 'Standard',
      'default_tag_sequence' => 'ATCACGTT',
      'study_alignments_in_bam' => 1,
      'study_contains_nonconsented_human' => 0
    } 
  };

  for my $o (($tag_zero, $tag_spiked, $tag_first, $tag_last)) {
    my $rpt_list = $o->rpt_list;
    ok (!defined $o->id_run, "id_run not defined for $rpt_list");
    for my $method ( qw/
                         sample_id sample_name sample_common_name
                         study_id study_name reference_genome
                         library_id library_name library_type
                         default_tag_sequence
                       /) {
      is ($o->$method, $expected->{$rpt_list}->{$method}, "$method for $rpt_list");
    }
    ok ($o->study_alignments_in_bam, "alignment true for $rpt_list");
    ok (!$o->study_contains_nonconsented_human, "nonconsented_human false for $rpt_list");
  }
  
  ok ($tag_spiked->is_phix_spike, 'is phix spike');
  ok (!$tag_first->is_phix_spike, 'is not phix spike');
  ok (!$tag_zero->is_phix_spike, 'is not phix spike');

  is (join(q[:], $tag_zero->study_names), 'Illumina Controls:NovaSeq testing',
    'study names including spiked phix');
  is (join(q[:], $tag_zero->study_names(1)), 'Illumina Controls:NovaSeq testing',
    'sudy names including spiked phix');
  is (join(q[:], $tag_zero->study_names(0)), 'NovaSeq testing',
    'study names excluding spiked phix');

  my @sample_names = qw/
    5318STDY7462457 5318STDY7462458 5318STDY7462459 5318STDY7462460 5318STDY7462461
    5318STDY7462462 5318STDY7462463 5318STDY7462464 5318STDY7462465 5318STDY7462466
    5318STDY7462467 5318STDY7462468 5318STDY7462469 5318STDY7462470 5318STDY7462471
    5318STDY7462472 5318STDY7462473 5318STDY7462474 5318STDY7462475 5318STDY7462476
    5318STDY7462477  /;
  
  is (join(q[:], $tag_zero->sample_names(0)), join(q[:], @sample_names),
    'sample names excluding spiked phix');
  push @sample_names, 'phiX_for_spiked_buffers';
  is (join(q[:], $tag_zero->sample_names()), join(q[:], @sample_names),
    'sample names including spiked phix');
  is (join(q[:], $tag_zero->sample_names(1)), join(q[:], @sample_names),
    'sample names including spiked phix');
};

subtest 'Aggregation across lanes for non-pools' => sub {
  plan tests => 13;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/test40_lims/samplesheet_rapidrun_nopool.csv';
  my @merged = st::api::lims->new(id_run => 22672)->aggregate_xlanes();

  my $l = $merged[0];
  is (scalar @merged, 1, 'one object returned');
  is ($l->rpt_list, '22672:1;22672:2', 'correct rpt_list');
  ok (!defined $l->id_run, "id_run not defined");
  ok (!$l->is_phix_spike, 'is not phix spike');

  my $expected = {
    'sample_id' => '2917461',
    'sample_name' => '4600STDY6702635',
    'sample_common_name' => 'Homo sapiens',
    'study_id' => 4600,
    'study_name' => 'Osteosarcoma_WGBS',
    'reference_genome' => 'Not suitable for alignment',
    'library_id' => '18914827',
    'library_name' => '18914827',
    'library_type' => 'Bisulphite pre quality controlled',
    'study_alignments_in_bam' => 1,
    'study_contains_nonconsented_human' => 0 
  };

  for my $method ( qw/
                       sample_id sample_name sample_common_name
                       study_id study_name reference_genome
                       library_id library_name library_type
                     /) {
    is ($l->$method, $expected->{$method}, "$method");
  }
};

subtest 'Aggregation across lanes for a tag' => sub {
  plan tests => 13;
 
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/test40_lims/samplesheet_novaseq4lanes.csv';

  my $l = st::api::lims->new(rpt_list => '25846:1:1;25846:2:1');

  my $e = qr/id_run and position are expected as arguments/;
  throws_ok { $l->create_lane_object() } $e, 'no arguments - error';
  throws_ok { $l->create_lane_object(1) } $e, 'one argument - error';
  throws_ok { $l->create_lane_object(1, 0) } $e,
    'one of argument is false - error';

  for my $p ((1,2)) {
    my $lane_l = $l->create_lane_object(25846, $p);
    is ($lane_l->id_run, 25846, 'run id is 25846');
    is ($lane_l->position, $p, "position is $p");
    is ($lane_l->rpt_list, undef, 'rpt_list is undefined');
    is ($lane_l->tag_index, undef, 'tag index is undefined');
    ok ($lane_l->is_pool, 'the entity is a pool');
  }
};

1;
