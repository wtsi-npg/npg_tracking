use strict;
use warnings;
use Test::More tests => 10;
use Test::Exception;
use List::MoreUtils qw/all none uniq/;
use File::Slurp;
use File::Temp qw/tempdir/;
use Moose::Meta::Class;

use_ok('npg_tracking::glossary::rpt');
use_ok('st::api::lims');

my $tmp_dir = tempdir( CLEANUP => 1 );

my $class = Moose::Meta::Class->create_anon_class(roles=>[qw/npg_testing::db/]);
my $schema_wh = $class->new_object({})->create_test_db(
  q[WTSI::DNAP::Warehouse::Schema], q[t/data/fixtures_lims_wh]
);

subtest 'Create lane object from plex object' => sub {
  plan tests => 25;
 
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/test40_lims/samplesheet_novaseq4lanes.csv';

  my $l = st::api::lims->new(rpt_list => '25846:1:1;25846:2:1');

  my $e = qr/id_run and position are expected as arguments/;
  throws_ok { $l->create_lane_object() } $e, 'no arguments - error';
  throws_ok { $l->create_lane_object(1) } $e, 'one argument - error';
  throws_ok { $l->create_lane_object(1, 0) } $e,
    'one of argument is false - error';

  my $test_lane = sub {
    my ($lane_l, $id_run, $position) = @_;
    is ($lane_l->id_run, $id_run, "run id is $id_run");
    is ($lane_l->position, $position, "position is $position");
    is ($lane_l->rpt_list, undef, 'rpt_list is undefined');
    is ($lane_l->tag_index, undef, 'tag index is undefined');
    ok ($lane_l->is_pool, 'the entity is a pool');
  };

  for my $p ((1,2)) {
    my $lane = $l->create_lane_object(25846, $p);
    $test_lane->($lane, 25846, $p);
  }

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = q[];
  
  my $id_run = 47995;
  my @objects = ();
  push @objects,  st::api::lims->new(
    id_run           => $id_run,
    position         => 1,
    tag_index        => 1,
    id_flowcell_lims => 98292,
    driver_type      => 'ml_warehouse',
    mlwh_schema      => $schema_wh,
  );
  
  $l = st::api::lims->new(
    id_run           => $id_run,
    id_flowcell_lims => 98292,
    driver_type      => 'ml_warehouse',
    mlwh_schema      => $schema_wh,
  );
  $l = ($l->children())[0];
  push @objects, ($l->children())[0];
  
  for my $l_obj (@objects) { 
    my $lane = $l_obj->create_lane_object($id_run, 2);
    is ($lane->driver->mlwh_schema, $schema_wh,
      'the original db connection is retained');
    $test_lane->($lane, $id_run, 2);
  }
};

subtest 'Create tag zero object' => sub {
  plan tests => 14;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/test40_lims/samplesheet_novaseq4lanes.csv';

  my $l = st::api::lims->new(id_run => 25846);
  throws_ok { $l->create_tag_zero_object() } qr/Position should be defined/,
    'method cannot be called on run-level object';
  $l = st::api::lims->new(rpt_list => '25846:2:1');
  throws_ok { $l->create_tag_zero_object() } qr/Position should be defined/,
    'method cannot be called on an object for a composition';

  my $description = 'st::api::lims object, driver - samplesheet, ' .
    'id_run 25846, ' .
    'path t/data/test40_lims/samplesheet_novaseq4lanes.csv, ' .
    'position 3, tag_index 0';
  $l = st::api::lims->new(id_run => 25846, position => 3);
  is ($l->create_tag_zero_object()->to_string(), $description,
    'created tag zero object from lane-level object');
  $l = st::api::lims->new(id_run => 25846, position => 3, tag_index => 5);
  is ($l->create_tag_zero_object()->to_string(), $description,
    'created tag zero object from plex-level object');

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = q[];
  
  my $id_run = 47995;
  my @objects = ();
  push @objects,  st::api::lims->new(
    id_run           => $id_run,
    position         => 1,
    id_flowcell_lims => 98292,
    driver_type      => 'ml_warehouse',
    mlwh_schema      => $schema_wh,
  );
  
  $l = st::api::lims->new(
    id_run           => $id_run,
    id_flowcell_lims => 98292,
    driver_type      => 'ml_warehouse',
    mlwh_schema      => $schema_wh,
  );
  $l = ($l->children())[0];
  push @objects, ($l->children())[0];
  
  for my $l_obj (@objects) { 
    my $t0 = $l_obj->create_tag_zero_object();
    is ($t0->driver->mlwh_schema, $schema_wh,
      'the original db connection is retained');
    my @names = $t0->sample_names();
    my @uuids = $t0->sample_uuids();
    is (@names, 18, '18 sample names are retrieved');
    is (@uuids, 18, '18 sample uuids are retrieved');
    is ($names[0], '6751STDY13219539', 'first sample name is correct');
    is ($uuids[0], '5832d018-56a6-11ed-a8fb-fa163eea3084', 'first sample uuid is correct');
  }
};

subtest 'Error conditions in aggregation by library' => sub {
  plan tests => 7;

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

  my $emassage =
    "Invalid lane numbers in list of lanes to exclude from the merge:";
  throws_ok { st::api::lims->aggregate_libraries(\@lane_lims, [qw/foo 3/]) }
    qr/$emassage\sfoo, 3/, 'lane number cannot be a string';
  throws_ok { st::api::lims->aggregate_libraries(\@lane_lims, [1.1, 2]) }
    qr/$emassage\s1.1, 2/, 'lane number cannot be a float';
  throws_ok { st::api::lims->aggregate_libraries(\@lane_lims, [-3]) }
    qr/$emassage\s-3/, 'lane number cannot be a negative integer';
  throws_ok { st::api::lims->aggregate_libraries(\@lane_lims, [0]) }
    qr/$emassage\s0/, 'lane number cannot be zero';
};

subtest 'Allow duplicate libraries with different tag indexes' => sub {
  plan tests => 6;

  # Real life example: Chromium single cell ATAC libraries have 4 copies
  # of each sample in a lane, each with a different tag.
  # This should not cause an error.
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/samplesheet/samplesheet_singlecell_48460.csv';
  my @lane_lims = st::api::lims->new(id_run => 48460)->children;
  my $lims;
  lives_ok { $lims = st::api::lims->aggregate_libraries(\@lane_lims) }
    'no error since grouping by library ID and tag index';
  is (scalar @{$lims->{merges}}, 28, '28 merged libraries'); 
  is (scalar @{$lims->{singles}}, 2, '2 single libraries');

  # Testing below that if one library in a potentially meargeable lane
  # is a singleton, the whole lane is excluded from the merge.
 
  my $content = read_file('t/data/samplesheet/samplesheet_47995.csv');
  # Make library id of tag 1 lane 1 the same as for tag 2 lane 3.
  $content =~ s/1,65934716,/1,69723083,/;
  # Change study id for all tags of lane 3 to be the same as in lane 1.
  $content =~ s/,6050,/,6751,/g;
  my $file_path = join q[/], $tmp_dir, 'samplesheet_multi_tag.csv';
  write_file($file_path, $content);

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = $file_path;
  @lane_lims = st::api::lims->new(id_run => 47995)->children;
  lives_ok { $lims = st::api::lims->aggregate_libraries(\@lane_lims) }
    'no error since grouping by library ID and tag index';
  my @unexpected = grep { $_ =~ / ^1: / }
                   map { $_->rpt_list } @{$lims->{merges}};
  is (scalar @unexpected, 0, 'lane 1 is not in merged entities');
  # 8 controls + 17 in lanes 1 and 2 each
  is (scalar @{$lims->{singles}}, 42, '42 single libraries');
};

subtest 'Aggregation by library for a NovaSeq standard flowcell' => sub {
  plan tests => 107;
  
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
  is (@{$lims->{'merges'}}, 21, 'list of merges contains 21 object');

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

  # Exclude lanes 1 and 3 from the merge
  $lims = st::api::lims->aggregate_libraries(\@lane_lims, [1,3]);
  is (@{$lims->{'singles'}}, 46, 'list of singles contains 46 objects');
  is (@{$lims->{'merges'}}, 21, 'list of merges contains 21 object');
  my @positions = uniq sort map { $_->position }
                  grep { ! $_->is_control }
                  @{$lims->{'singles'}};
  is (join(q[,], @positions), '1,3', 'lanes 1 and 3 are not merged');
  @expected_rpt_lists = _generate_rpt_lists($id_run, [2, 4], [(1 .. 21)]);
  @rpt_lists = map { $_->rpt_list } @{$lims->{'merges'}};
  is_deeply (\@rpt_lists, \@expected_rpt_lists, 'merges list - correct object'); 

  # Exclude lanes 1 and 5 from the merge
  lives_ok { $lims = st::api::lims->aggregate_libraries(\@lane_lims, [1,5]) }
    'asking to exclude a lane for which there is no data is not an error'; 
  @rpt_lists = map { $_->rpt_list } @{$lims->{'merges'}};
  @expected_rpt_lists = _generate_rpt_lists($id_run, [2, 3, 4], [(1 .. 21)]);
  is_deeply (\@rpt_lists, \@expected_rpt_lists, 'merges list - correct object');

  # Select two lanes out of four.
  $lims = st::api::lims->aggregate_libraries([$lane_lims[0], $lane_lims[2]], []);
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

subtest 'mlwarehouse driver in aggregation by library' => sub {
  plan tests => 5;

  my $class = Moose::Meta::Class->create_anon_class(roles=>[qw/npg_testing::db/]);
  my $schema_wh = $class->new_object({})->create_test_db(
    q[WTSI::DNAP::Warehouse::Schema], q[t/data/fixtures_lims_wh]
  );

  my $id_run = 47995;
  my @lane_lims = st::api::lims->new(
    id_run           => $id_run,
    id_flowcell_lims => 98292,
    driver_type      => 'ml_warehouse',
    mlwh_schema      => $schema_wh,
  )->children();
  my $lims = st::api::lims->aggregate_libraries(\@lane_lims);
  # Test that lims objects are viable, ie it is possible to retrieve
  # their properties.
  is (@{$lims->{'singles'}}, 8, 'list of singles contains 8 objects');
  lives_ok { $lims->{'singles'}->[0]->sample_name } 'can retrieve sample name';
  is (@{$lims->{'merges'}}, 87, 'list of merges contains 87 objects');
  lives_ok { $lims->{'merges'}->[0]->sample_name } 'can retrieve sample name';
  lives_ok { $lims->{'merges'}->[86]->sample_name } 'can retrieve sample name';
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
