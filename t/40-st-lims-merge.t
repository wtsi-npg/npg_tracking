use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;
use List::MoreUtils qw/all none/;
use File::Slurp;
use File::Temp qw/tempdir/;

use_ok('npg_tracking::glossary::rpt');
use_ok('st::api::lims');

my $tmp_dir = tempdir( CLEANUP => 1 );

subtest 'Aggregation across lanes for pools' => sub {
  plan tests => 82;
  
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
  ok ((none {defined $_->id_run} ($tag_zero, $tag_spiked, $tag_first, $tag_last)),
    "id_run not defined");

  _compare_properties([$tag_first, $tag_last, $tag_zero, $tag_spiked]);

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
  plan tests => 14;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/test40_lims/samplesheet_rapidrun_nopool.csv';
  my @merged = st::api::lims->new(id_run => 22672)->aggregate_xlanes();
  is (scalar @merged, 1, 'one object returned');
  my $l = $merged[0];
  is ($l->rpt_list, '22672:1;22672:2', 'correct rpt_list');
  ok (!defined $l->id_run, "id_run not defined");
  ok (!$l->is_phix_spike, 'is not phix spike');
  _compare_properties_2($l);
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

subtest 'Error conditions in aggregation by library' => sub {
  plan tests => 4;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/test40_lims/samplesheet_novaseq4lanes.csv';
  my @lane_lims = st::api::lims->new(id_run => 25846)->children;
  my @mixed_lanes = ($lane_lims[0]);
  my $ss_47995_path = 't/data/samplesheet/samplesheet_47995.csv';
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = $ss_47995_path;
  @lane_lims = st::api::lims->new(id_run => 47995)->children;
  push @mixed_lanes, $lane_lims[0];

  throws_ok { st::api::lims->aggregate_libraries(\@mixed_lanes) }
    qr/Multiple run IDs in a potential merge by library/,
    'data for a single run is expected';
  
  my $lane_1_lib = ($lane_lims[0]->children())[0];
  my $lane_2_lib = ($lane_lims[1]->children())[0];
  throws_ok {
    st::api::lims->aggregate_libraries([$lane_1_lib, $lane_2_lib, $lane_1_lib])
  } qr/Intra-lane merge is detected/, 'merges should be between lanes';

  my $content = read_file($ss_47995_path);
  $content =~ s/,6751,/,6752,/; # One change of the study id.
  my $file_path = join q[/], $tmp_dir, 'samplesheet_multi_study.csv';
  write_file($file_path, $content);
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = $file_path;
  @lane_lims = st::api::lims->new(id_run => 47995)->children;
  throws_ok { st::api::lims->aggregate_libraries(\@lane_lims) }
    qr/Multiple studies in a potential merge by library/,
    'can only merge libraries that belong to the same study';

  $content = read_file($ss_47995_path);
  # Make library id of tag 1 lane 1 the same as for tag 2 lane 3.
  $content =~ s/1,65934716,/1,69723083,/;
  # Change study id for all tags of lane 3 to be the same as in lane 1.
  $content =~ s/,6050,/,6751,/g;
  $file_path = join q[/], $tmp_dir, 'samplesheet_multi_tag.csv';
  write_file($file_path, $content);
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = $file_path;
  @lane_lims = st::api::lims->new(id_run => 47995)->children;
  throws_ok { st::api::lims->aggregate_libraries(\@lane_lims) }
    qr/Multiple tag indexes in a potential merge by library/,
    'can only merge libraries with teh same tag index';
};

subtest 'Aggregation by library for a NovaSeq standard flowcell' => sub {
  plan tests => 101;
  
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/test40_lims/samplesheet_novaseq4lanes.csv';
  # All lanes of this runs can be merged together.
  # The pool contains a spiked-in control.

  my $id_run = 25846;
  my @lane_lims = st::api::lims->new(id_run => $id_run)->children;
  my $lims = st::api::lims->aggregate_libraries(\@lane_lims);

  for my $key_name (qw/singles merges/) {
    ok (exists $lims->{$key_name}, "entry for $key_name exists");
    is (ref $lims->{$key_name}, 'ARRAY', 'the value is an array');
  }
  is (keys %{$lims}, 2, 'no unexpected keys');
  is (@{$lims->{'singles'}}, 4, 'list of singles contains 4 objects');
  is (@{$lims->{'merges'}}, 21, 'list of merges contains 21 objects');

  ok ( (all { $_->is_control } @{$lims->{'singles'}}),
    'all singles are spiked-in controls');
  ok ((none { defined $_->rpt_list } @{$lims->{'singles'}}),
    'rpt_list value is not defined for singles');
  ok ((all { $_->id_run == $id_run } @{$lims->{'singles'}}),
    'id_run is set correctly for singles');
  ok ((all { $_->tag_index == 888 } @{$lims->{'singles'}}),
    'tag_index is set correctly for singles');
  is ('1,2,3,4', join(q[,], map { $_->position } @{$lims->{'singles'}}),
    'objects are ordered in position acsending order');

  my @rpt_lists = map { $_->rpt_list } @{$lims->{'merges'}};
  my @expected_rpt_lists = _generate_rpt_lists($id_run, [(1 .. 4)], [(1 .. 21)]);
  is_deeply (\@rpt_lists, \@expected_rpt_lists,
      'merges list - correct object, correct sort order');
  
  for my $method_name (qw/id_run position tag_index/) {
    ok ((none { defined $_->$method_name } @{$lims->{'merges'}}),
      "$method_name is not defined");
  }
  ok ((all { $_->driver_type eq 'samplesheet' } @{$lims->{'merges'}}),
    'driver type is correct');

  _compare_properties([$lims->{'merges'}->[0], $lims->{'merges'}->[20]]);

  # Select two lanes out of four.
  $lims = st::api::lims->aggregate_libraries([$lane_lims[0], $lane_lims[2]]);
  is (@{$lims->{'singles'}}, 2, 'list of singles contains 2 objects');
  is (@{$lims->{'merges'}}, 21, 'list of merges contains 21 objects');
  @rpt_lists = map { $_->rpt_list } @{$lims->{'merges'}};
  @expected_rpt_lists = _generate_rpt_lists($id_run, [1, 3], [(1 .. 21)]);
  is_deeply (\@rpt_lists, \@expected_rpt_lists,
      'merges list - correct object, correct sort order');
  _compare_properties([$lims->{'merges'}->[0], $lims->{'merges'}->[20]]);

  # Select one lane only, No 2. Invoke the method on an instance.
  my $lane = $lane_lims[1]; 
  $lims = $lane->aggregate_libraries([$lane]);
  is (@{$lims->{'singles'}}, 22, 'list of singles contains 22 objects');
  is (@{$lims->{'merges'}}, 0, 'list of merges is empty');
  ok ((none { defined $_->rpt_list } @{$lims->{'singles'}}),
    'rpt_list value is not defined for singles');
  ok ((all { $_->id_run == $id_run && $_->position == 2} @{$lims->{'singles'}}),
    'id_run and position are set correctly for singles');
  my @tag_indexes = map { $_->tag_index } @{$lims->{'singles'}};
  is_deeply (\@tag_indexes, [(1 .. 21, 888)],
    'tag indexes are set correctly, correct sort order');
  ok ($lims->{'singles'}->[21]->is_control, 'tag 888 is flagged as control');
  ok ((none { $lims->{'singles'}->[$_]->is_control } (0 .. 20)),
    'all other objects are not marked as controls');
  _compare_properties([$lims->{'singles'}->[0], $lims->{'singles'}->[20]]);

  # Remove spiked-in controls from the samplesheet.
  my @lines = grep { $_ !~ /phiX_for_spiked_buffers/ }
              read_file($ENV{NPG_CACHED_SAMPLESHEET_FILE});
  my $file_path = join q[/], $tmp_dir, 'samplesheet.csv';
  write_file($file_path, @lines);
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = $file_path;
  @lane_lims = st::api::lims->new(id_run => $id_run)->children;
  $lims = st::api::lims->aggregate_libraries(\@lane_lims);
  is (@{$lims->{'singles'}}, 0, 'list of singles is empty');
  is (@{$lims->{'merges'}}, 21, 'list of merges contains 21 objects');
};

subtest 'Aggregation by library for non-pools' => sub {
  plan tests => 15;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/test40_lims/samplesheet_rapidrun_nopool.csv';
  my @lane_lims = st::api::lims->new(id_run => 22672)->children();
  my $lims = st::api::lims->aggregate_libraries(\@lane_lims);
  is (@{$lims->{'singles'}}, 0, 'list of singles is empty');
  is (@{$lims->{'merges'}}, 1, 'list of merges contains one object');
  my $l = $lims->{'merges'}->[0];
  is ($l->rpt_list, '22672:1;22672:2', 'correct rpt_list');
  _compare_properties_2($l);

  $lims = st::api::lims->aggregate_libraries([$lane_lims[0]]);
  is (@{$lims->{'singles'}}, 1, 'list of singles contains one object');
  is (@{$lims->{'merges'}}, 0, 'list of merges is empty');
};

subtest 'Multiple lane sets in aggregation by library' => sub {
  plan tests => 11;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/samplesheet/samplesheet_47995.csv';
  my $id_run = 47995;
  my @lane_lims = st::api::lims->new(id_run => $id_run)->children();
  # Reverse the order of the argument list.
  my $lims = st::api::lims->aggregate_libraries([reverse @lane_lims]);

  is (@{$lims->{'singles'}}, 8, 'list of singles contains 8 objects');
  ok ((all {$_->is_control} @{$lims->{'singles'}}), 'all singles are controls');
  ok ((all {$_->tag_index == 888} @{$lims->{'singles'}}), 'all singles have tag 888');
  is_deeply ([(1 .. 8)], [map {$_->position} @{$lims->{'singles'}}],
    'correct sort order');

  is (@{$lims->{'merges'}}, 87, 'list of merges contains 87 objects');
  my %lanes_tags = (
    '1,2' => [(1 .. 17)],
    '3,4' => [(1 .. 10)],
    '5,6' => [(1 .. 22)],
    '7,8' => [(1 .. 38)],
  );
  my @expected_rpt_lists = ();
  for my $lane_set (sort keys %lanes_tags) {
    my @lanes = split q[,], $lane_set;
    push @expected_rpt_lists,
      _generate_rpt_lists($id_run, \@lanes, $lanes_tags{$lane_set});
  }
  my @rpt_lists = map { $_->rpt_list } @{$lims->{'merges'}};
  is_deeply (\@rpt_lists, \@expected_rpt_lists,
    'merges list - correct object, correct sort order');

  # Two lanes to be merged (1, 2), two lanes (4, 8) as is.
  $lims = st::api::lims->aggregate_libraries(
    [$lane_lims[3], $lane_lims[1], $lane_lims[0], $lane_lims[7]]);

  my $expected_num_singles = scalar @{$lanes_tags{'3,4'}}
                             + scalar @{$lanes_tags{'7,8'}}
                             + 4; # Controls for lanes 1,2,4,8.
  is (@{$lims->{'singles'}}, $expected_num_singles,
    "list of singles contains $expected_num_singles objects");
  is (scalar (grep {$_->is_control} @{$lims->{'singles'}}), 4,
    '4 singles are controls');
  
  @expected_rpt_lists = map {join q[:], $id_run, $_, 888} (1,2);
  push @expected_rpt_lists,
    _generate_rpt_lists($id_run, [4], $lanes_tags{'3,4'}), "${id_run}:4:888";
  push @expected_rpt_lists,
    _generate_rpt_lists($id_run, [8], $lanes_tags{'7,8'}), "${id_run}:8:888"; 
  @rpt_lists = ();
  foreach my $l (@{$lims->{'singles'}}) {
    push @rpt_lists, npg_tracking::glossary::rpt->deflate_rpts([$l]);
  }
  is_deeply (\@rpt_lists, \@expected_rpt_lists,
    'singles list - correct object, correct sort order');

  is (@{$lims->{'merges'}}, 17, 'list of merges contains 17 objects');
  @expected_rpt_lists = _generate_rpt_lists($id_run, [1,2], $lanes_tags{'1,2'});
  @rpt_lists = map { $_->rpt_list } @{$lims->{'merges'}};
  is_deeply (\@rpt_lists, \@expected_rpt_lists,
    'merges list - correct object, correct sort order');
};

sub _generate_rpt_lists {
  my ($id_run, $positions, $tag_indexes) = @_;
  my @expected_rpt_lists = ();
  foreach my $tag_index (@{$tag_indexes}) {
    my @rpt_list = ();
    for my $position (@{$positions}) {
      push @rpt_list, join q[:], $id_run, $position, $tag_index;
    }
    push @expected_rpt_lists, join q[;], @rpt_list;
  }
  return @expected_rpt_lists;
}

sub _compare_properties {
  my $lims_objects = shift;

  my $expected_props = [
    {
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
    },
    {
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
    {
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
    {
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
    }
  ];

  my $num_objects = @{$lims_objects};
  for my $i ((0 .. $num_objects-1)) {
    my $o = $lims_objects->[$i];
    my $description = $o->rpt_list ? $o->rpt_list : $o->to_string;
    my $expected = $expected_props->[$i];
    for my $method ( qw/
                        sample_id sample_name sample_common_name
                        study_id study_name reference_genome
                        library_id library_name library_type
                        default_tag_sequence study_alignments_in_bam
                       /) {
      is ($o->$method, $expected->{$method}, "$method for $description");
    }
    ok (!$o->study_contains_nonconsented_human, "nonconsented_human false for $description");
  }

  return;
}

sub _compare_properties_2 {
  my $obj = shift;
  my $rpt_list = $obj->rpt_list;
  my %expected = (
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
  );
  for my $method ( sort keys %expected) {
    is ($obj->$method, $expected{$method}, "$method for $rpt_list");
  }

  return;
}

1;
