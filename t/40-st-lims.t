use strict;
use warnings;
use Test::More tests => 15;
use Test::Exception;
use Test::Warn;
use Moose::Meta::Class;

my $num_delegated_methods = 45;

use_ok('st::api::lims');

subtest 'Test trim' => sub {
  plan tests => 4;

  my $value = 'some other';
  is(st::api::lims->_trim_value($value), $value, 'nothing trimmed');
  is(st::api::lims->_trim_value("  $value"), $value, 'leading space trimmed');
  is(st::api::lims->_trim_value("  $value  "), $value, 'space trimmed');
  is(st::api::lims->_trim_value("  "), undef, 'white space string trimmed to undef');
};

subtest 'Driver type, methods and driver build' => sub {
  plan tests => 27;

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
  ok (-d $ENV{NPG_CACHED_SAMPLESHEET_FILE});
  lives_ok {$l = st::api::lims->new(id_run => 10262,)}
    'no error creating an object with samplesheet file defined in env var';
  is ($l->driver_type, 'samplesheet', 'driver type is samplesheet');
  throws_ok { $l->path }
    qr/Attribute \(path\) does not pass the type constraint/,
    'samplesheet cannot be a directory';

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/samplesheet/non-existing';
  ok (not -e $ENV{NPG_CACHED_SAMPLESHEET_FILE});
  lives_ok {$l = st::api::lims->new(id_run => 10262,)}
    'no error creating an object with samplesheet file defined in env var';
  is ($l->driver_type, 'samplesheet', 'driver type is samplesheet');
  throws_ok {$l->children}
    qr/Attribute \(path\) does not pass the type constraint/,
    'samplesheet file should exist';

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/samplesheet/non-existing';
  lives_ok {$l = st::api::lims->new(id_run => 10262, path => $ss_path)}
    'no error creating an object with samplesheet file defined in env var and path given';
  is ($l->driver_type, 'samplesheet', 'driver type is samplesheet');
  lives_ok {$l->children} 'given path takes precedence';

  throws_ok { st::api::lims->new(
    id_run => 6551, driver_type => 'some') }
    qr/Can\'t locate st\/api\/lims\/some\.pm in \@INC/,
    'unknown driver type specified - error';

  is (st::api::lims->cached_samplesheet_var_name, 'NPG_CACHED_SAMPLESHEET_FILE',
    'get name of the cached samplesheet env var via a class method');

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/samplesheet/miseq_default.csv';
  $l = st::api::lims->new(id_run => 6551);
  is($l->driver_type, 'samplesheet');
  isa_ok ($l->driver(), 'st::api::lims::samplesheet');

  use_ok('st::api::lims::samplesheet');
  $l = st::api::lims->new(id_run => 6551,
                          driver => st::api::lims::samplesheet->new(
                            id_run => 6551,
                            path   => $ENV{NPG_CACHED_SAMPLESHEET_FILE}));
  is($l->driver_type, 'samplesheet', 'driver type from the driver object');

  is(scalar st::api::lims->driver_method_list(), $num_delegated_methods,
    'driver method list length');
  is(scalar st::api::lims::driver_method_list_short(), $num_delegated_methods,
    'short driver method list length');
  is(scalar st::api::lims->driver_method_list_short(), $num_delegated_methods,
    'short driver method list length');
  is(scalar st::api::lims::driver_method_list_short(qw/sample_name/),
    $num_delegated_methods-1, 'one method removed from the list');
  is(scalar st::api::lims->driver_method_list_short(qw/sample_name study_name/),
    $num_delegated_methods-2, 'two methods removed from the list');
};

subtest 'Setting return value for primary attributes' => sub {
  plan tests => 21;

  my @other = qw/id_flowcell_lims flowcell_barcode/;
  my $ss_path = 't/data/samplesheet/miseq_default.csv';
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = $ss_path;

  my $lims = st::api::lims->new(id_run => 6551, position => 1, tag_index => 0);
  is ($lims->driver_type, 'samplesheet', 'samplesheet driver');

  for my $attr (@other) {
    is ($lims->$attr, undef, "$attr is undefined");
  }
  is ($lims->id_run, 6551, 'id run is set correctly');
  is ($lims->path, $ss_path, 'path is set correctly');
  is ($lims->position, 1, 'position is set correctly');
  is ($lims->tag_index, 0, 'tag_index is set to zero');
  ok ($lims->is_pool, 'tag zero is a pool');

  my $lane_lims =  st::api::lims->new(id_run => 6551, position => 1);
  $lims = st::api::lims->new(driver    => $lane_lims->driver(),
                             id_run    => 6551,
                             position  => 1,
                             tag_index => 0);
  is ($lims->id_run, 6551, 'id run is set correctly');
  is ($lims->position, 1, 'position is set correctly');
  is ($lims->tag_index, 0, 'tag_index is set to zero');
  ok ($lims->is_pool, 'tag zero is a pool');
  ok (!$lims->is_composition, 'tag zero is not a composition');
  is($lims->to_string,
    'st::api::lims object, driver - samplesheet, id_run 6551, ' .
    'path t/data/samplesheet/miseq_default.csv, position 1, tag_index 0',
    'object as string');

  $lims = st::api::lims->new(rpt_list => '6551:1');
  my @a = @other;
  push @a, qw/id_run position tag_index/;
  is ($lims->rpt_list, '6551:1', 'rpt_list is set correctly');
  ok ($lims->is_composition, 'is a composition');
  for my $attr (@a) {
    is($lims->$attr, undef, "$attr is undefined");
  }
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
  my $is_pool;
  warning_is { $is_pool = $ss->is_pool }
    q[id_run is set to Experiment Name, 10262],
    'warning when setting id_run from Experiment Name';
  is ($is_pool, 0, 'is_pool false on run level');
  is ($ss->is_control, undef, 'is_control undef on run level');
  is ($ss->library_id, undef, 'library_id undef on run level');
  is ($ss->library_name, undef, 'library_name undef on run level');
  is ($ss->id_run, 10262, 'id_run undefined');
  @lanes = $ss->children;
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

subtest 'Lane-level and tag zero objects via samplesheet driver' => sub {
  plan tests => 20;

  my $path = 't/data/samplesheet/miseq_default.csv';

  my $l;
  lives_ok { $l = st::api::lims->new(
    id_run => 10262, position => 2, path => $path)
  } 'no error instantiation an object for a non-existing lane';
  throws_ok { $l->library_id }
    qr/Position 2 not defined in/,
    'error invoking a driver method on an object for a non-existing lane';

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = $path;

  my $lane = st::api::lims->new(id_run => 10262, position => 1);
  is ($lane->tag_index, undef, 'tag index is undefined for a lane');
  my $tag_zero = st::api::lims->new(id_run => 10262, position => 1, tag_index => 0);
  is ($tag_zero->tag_index, 0, 'tag index is zero for tag zero');
  for my $ss (($lane, $tag_zero)) {
    is ($ss->path, $path,
      'samplesheet path captured from NPG_CACHED_SAMPLESHEET_FILE')
       or diag explain $ss;
    is ($ss->position, 1, 'correct position');
    is ($ss->is_pool, 1, 'entity is a pool');
    is (scalar $ss->children, 96, '96 plexes returned');
    is ($ss->library_id, undef, 'library_id undefined');
    is ($ss->sample_name, undef, 'sample name is undefined');
    is ($ss->default_tag_sequence, undef, 'default tag sequence undefined');
    is ($ss->tag_sequence, undef, 'tag sequence undefined');
  }
};

subtest 'Plex-level objects via samplesheet driver' => sub {
  plan tests => 10;

  my $path = 't/data/samplesheet/miseq_default.csv';
  my $l;
  lives_ok { $l = st::api::lims->new(
    id_run => 10262, position => 1, tag_index => 999, path => $path
  )} 'no error instantiation an object for a non-existing tag_index';
  throws_ok { $l->children() }
    qr/Tag index 999 not defined in/,
    'error invoking a driver method on an object for a non-existing tag_index';

  $l =st::api::lims->new(
    id_run => 10262, position => 1, tag_index => 3, path => $path);
  is ($l->position, 1, 'correct position');
  is ($l->tag_index, 3, 'correct tag_index');
  is ($l->is_pool, 0, 'plex is not a pool');
  is ($l->default_tag_sequence, 'TTAGGCAT', 'correct default tag sequence');
  is ($l->tag_sequence, $l->default_tag_sequence,
    'tag sequence is the same as default tag sequence');
  is ($l->library_id, 7583413, 'library id is correct');
  is ($l->sample_name, 'LIA_3', 'sample name is correct');
  is (scalar $l->children, 0, 'zero children returned'); 
};

subtest 'Samplesheet driver for a one-component composition' => sub {
  plan tests => 26;

  my $path = 't/data/samplesheet/miseq_default.csv';
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = $path;

  my $ss=st::api::lims->new(rpt_list => '10262:1:3', driver_type => 'samplesheet');
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

subtest 'Samplesheet driver for arbitrary compositions' => sub {
  plan tests => 69;

  my $path = 't/data/samplesheet/novaseq_multirun.csv';
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = $path;
  my $rpt_list = '26480:1:9;26480:2:9;26480:3:9;26480:4:9;28780:2:4';

  my $ss=st::api::lims->new(rpt_list => $rpt_list);
  is ($ss->rpt_list, $rpt_list, 'rpt list as given');
  is ($ss->id_run, undef, 'run id undefined');
  is ($ss->position, undef, 'position undefined');
  is ($ss->tag_index, undef, 'tag_index undefined');
  ok (!$ss->is_pool, 'not a pool');
  is ($ss->is_composition, 1, 'this is a composition');
  my @children = $ss->children();
  is (scalar @children, 5, 'five children');

  foreach my $o ((@children, $ss)) {
    is($o->default_tag_sequence, 'AGTTCAGG', 'tag sequence');
    is($o->default_tagtwo_sequence, 'CCAACAGA', 'tag2 sequence');
    is($o->default_library_type, 'HiSeqX PCR free', 'library type');
    is($o->sample_name, '7592352', 'sample name');
    is($o->study_name, 'UK Study', 'study name');
    is($o->library_name, '22802061', 'library name');
    is($o->reference_genome, 'Homo_sapiens (GRCh38_15_plus_hs38d1) [minimap2]',
      'reference genome');
  }

  $ss = $children[0];
  ok ($ss->driver && (ref $ss->driver eq 'st::api::lims::samplesheet'), 'correct driver');
  is ($ss->driver_type, 'samplesheet', 'driver type is samplesheet');
  is ($ss->rpt_list, undef, 'rpt list is undefined');
  is ($ss->id_run, 26480, 'correct run id');
  is ($ss->position, 1, 'correct position');
  is ($ss->tag_index, 9, 'correct tag_index');
  ok (!$ss->is_pool, 'plex is not a pool');
  is ($ss->is_composition, 0, 'not a composition');

  $ss = $children[1];
  is ($ss->id_run, 26480, 'correct run id');
  is ($ss->position, 2, 'correct position');
  is ($ss->tag_index, 9, 'correct tag_index');

  $ss = $children[2];
  is ($ss->id_run, 26480, 'correct run id');
  is ($ss->position, 3, 'correct position');
  is ($ss->tag_index, 9, 'correct tag_index');

  $ss = $children[3];
  is ($ss->id_run, 26480, 'correct run id');
  is ($ss->position, 4, 'correct position');
  is ($ss->tag_index, 9, 'correct tag_index');

  $ss = $children[4];
  is ($ss->id_run, 28780, 'correct run id');
  is ($ss->position, 2, 'correct position');
  is ($ss->tag_index, 4, 'correct tag_index');
};

subtest 'Dual index' => sub {
  plan tests => 16;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/samplesheet/dual_index_extended.csv';
  my $l = st::api::lims->new(id_run => 6946);
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
};

subtest 'Insert size' => sub {
  plan tests => 20;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/samplesheet/4pool4libs_extended.csv';

  my $lims = st::api::lims->new(id_run => 9999);
  is_deeply($lims->required_insert_size, {}, 'no insert size on run level');
  
  $lims = st::api::lims->new(id_run => 9999, position => 1);
  my $id = $lims->library_id;
  my $insert_size = $lims->required_insert_size;
  is (keys %{$insert_size}, 1, 'one entry in the insert size hash');
  is ($insert_size->{$id}->{q[from]}, 400, 'required FROM insert size');
  is ($insert_size->{$id}->{q[to]}, 550, 'required TO insert size');
  
  $lims = st::api::lims->new(id_run => 9999, position => 7);
  ok ($lims->is_pool, 'lane is a pool');
  $insert_size = $lims->required_insert_size;
  is (keys %{$insert_size}, 2, 'two entries in the insert size hash');
  $id = '8324594';
  is ($insert_size->{$id}->{q[from]}, 100, 'required FROM insert size');
  is ($insert_size->{$id}->{q[to]}, 1000, 'required TO insert size'); 
  $id = '8324595';
  is ($insert_size->{$id}->{q[from]}, 100, 'required FROM insert size');
  is ($insert_size->{$id}->{q[to]}, 1000, 'required TO insert size');
  ok (!exists $insert_size->{q[6946_7_ACAACGCAAT]}, 'no required insert size');
  
  for my $l ((
    st::api::lims->new(id_run => 9999, position => 7, tag_index => 77),
    st::api::lims->new(rpt_list => '9999:7:77')
  )) {
    $insert_size = $l->required_insert_size;
    is (keys %{$insert_size}, 1, 'one entry in the insert size hash');
    is ($insert_size->{$id}->{q[from]}, 100, 'required FROM insert size');
    is ($insert_size->{$id}->{q[to]}, 1000,'required TO insert size');
  }

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    q[t/data/samplesheet/samplesheet_47995.csv];
  
  $lims = st::api::lims->new(rpt_list => '47995:1:3;47995:2:3');
  $insert_size = $lims->required_insert_size;
  is (keys %{$insert_size}, 1, 'one entry in the insert size hash');
  $id = '65934645';
  is ($insert_size->{$id}->{q[from]}, 100, 'required FROM insert size');
  is ($insert_size->{$id}->{q[to]}, 400,'required TO insert size');
};

subtest 'Study and sample properties' => sub {
  plan tests => 75;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/samplesheet/4pool4libs_extended.csv';
  
  # A simple non-indexed lane.
  my $lims = st::api::lims->new(id_run => 9999, position => 1);
  is( $lims->study_title(), 'Haemonchus contortus Ivermectin Resistance',
    'study title' );
  is( $lims->study_name(), 'Haemonchus contortus Ivermectin Resistance',
    'study name');
  is( $lims->study_accession_number(), 'ERP000430', 'study accession number');
  is( $lims->study_publishable_name(), 'ERP000430',
    'study accession number returned as publishable name');
  ok( !$lims->alignments_in_bam, 'no alignments');
  is( $lims->sample_reference_genome, 'Haemonchus_contortus (V1_21June13)',
    'sample reference genome');
  is( $lims->study_reference_genome, q[ ], 'study reference genome');
  is( $lims->reference_genome, 'Haemonchus_contortus (V1_21June13)',
    'reference genome');

  # Individual plex.
  $lims = st::api::lims->new(id_run => 9999, position => 7, tag_index=> 76);
  ok( $lims->alignments_in_bam, 'do alignments');
  like( $lims->study_title(),
    qr/Mouse model to quantify genotype-epigenotype variations /,
    'study title');
  is( $lims->study_name(),
    'Mouse model to quantify genotype-epigenotype variations_RNA',
    'study name');
  is( $lims->study_publishable_name(), 'ERP002223',
    'accession is returned as study publishable name');
  is( $lims->sample_publishable_name(), 'ERS354534',
    'sample publishable name returns accession');
  ok( !$lims->separate_y_chromosome_data, 'do not separate y chromosome data');
  is( $lims->sample_reference_genome, undef, 'sample reference genome');
  is( $lims->study_reference_genome, 'Mus_musculus (GRCm38)',
    'study reference genome');
  is( $lims->reference_genome, 'Mus_musculus (GRCm38)', 'reference genome');

  # Indexed lane and tag zero for the same lane.
  for my $l (
    st::api::lims->new(id_run => 9999, position => 7),
    st::api::lims->new(id_run => 9999, position => 7, tag_index => 0)
  ) { 
    is( $l->study_name(),
      'Mouse model to quantify genotype-epigenotype variations_RNA',
      'study name');
    is( $l->sample_name, undef, 'sample name undefined');
    is( $l->sample_reference_genome, undef, 'sample reference genome');
    is( $l->study_reference_genome, 'Mus_musculus (GRCm38)',
      'study reference genome');
    is( $l->reference_genome, 'Mus_musculus (GRCm38)', 'reference genome');
  }

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/samplesheet/samplesheet_47539.csv';
  
  # Multiple sample references within a pool, the same study.
  my $study_name = 'SeqOps Novaseq X Validation';
  my $ref = 'Homo_sapiens (GRCh38_15_plus_hs38d1) [minimap2]';
  for my $l (
    st::api::lims->new(id_run => 47539, position => 1),
    st::api::lims->new(id_run => 47537, position => 1, tag_index => 0),
    st::api::lims->new(rpt_list => '47539:1'),
    st::api::lims->new(rpt_list => '47539:1:0')
  ) { 
    is( $l->study_name(), $study_name, 'study name');
    is( $l->sample_name, undef, 'sample name undefined');
    is( $l->sample_reference_genome, undef, 'sample reference genome undefined');
    is( $l->study_reference_genome, $ref, 'study reference genome');
    is( $l->reference_genome, undef, 'no fallback to study');
  }

  my $ref2 = 'Homo_sapiens (GRCh38_full_analysis_set_plus_decoy_hla)';
  $lims = st::api::lims->new(id_run => 47537, position => 1, tag_index => 1);
  is( $lims->study_name(), $study_name, 'study name');
  is( $lims->sample_name, 'RefStds_PCR8021331', 'sample name');
  is( $lims->sample_reference_genome, $ref2, 'sample reference genome');
  is( $lims->study_reference_genome, $ref, 'study reference genome');
  is( $lims->reference_genome, $ref2, 'reference genome as for the sample');
  
  $lims = st::api::lims->new(id_run => 47537, position => 4, tag_index => 2);
  is( $lims->study_name(),$study_name, 'study name');
  is( $lims->sample_name, 'RefStds_PCR-free8023829', 'sample name');
  is( $lims->sample_reference_genome, undef, 'sample reference genome undefined');
  is( $lims->study_reference_genome, $ref, 'study reference genome');
  is( $lims->reference_genome, $ref, 'reference genome - fall back to study');

  $lims = st::api::lims->new(id_run => 47537, position => 4, tag_index => 1);
  is( $lims->sample_reference_genome, $ref2, 'sample reference genome');
  is( $lims->study_reference_genome, $ref, 'study reference genome');
  is( $lims->reference_genome, $ref2, 'reference genome');

  # The fact that in tests below sample_reference_genome and, as a consequence,
  # reference_genome methods return a reference rather than stay undefined
  # seems wrong. The two samples in the pool have the same referenceand and
  # for one it is undefined. If in this case no value was considered as an
  # unknown reference, both methods would have returned an undefined value.
  for my $l (
    st::api::lims->new(id_run => 47539, position => 4),
    st::api::lims->new(id_run => 47537, position => 4, tag_index => 0),
  ) {
    is( $l->sample_reference_genome, $ref2, 'sample reference genome');
    is( $l->study_reference_genome, $ref, 'study reference genome');
    is( $l->reference_genome, $ref2, 'ref genome');
  }

  $lims = st::api::lims->new(rpt_list => '47539:1:0;47539:4:0'); 
  is( $lims->sample_reference_genome, undef, 'sample reference genome undefined');
  is( $lims->study_reference_genome, $ref, 'study reference genome');
  is( $lims->reference_genome, undef, 'ref genome');

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/samplesheet/samplesheet_27483.csv';
  # Spiked lane, no sample references, single study.
  $ref = 'Homo_sapiens (GRCh38_15 + ensembl_78_transcriptome)';
  for my $l (
    st::api::lims->new(id_run => 27483, position => 8),
    st::api::lims->new(id_run => 27483, position => 8, tag_index => 0),
  ) {
    is( $l->sample_reference_genome, undef, 'sample reference genome undefined');
    is( $l->study_reference_genome, $ref, 'study reference genome');
    is( $l->reference_genome, $ref, 'fall back to study genome');
  }
  
};

subtest 'Bait name' => sub {
  plan tests => 8;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/samplesheet/samplesheet_7753.csv';
  
  my $lims = st::api::lims->new(id_run => 7753);
  is($lims->bait_name, undef, 'bait name undefined on run level');
  $lims = st::api::lims->new(id_run => 7753, position => 1);
  is($lims->bait_name, undef, 'bait name undefined on a pool level');
  $lims = st::api::lims->new(id_run => 7753, position => 1, tag_index=> 2);
  is($lims->bait_name,'Human all exon 50MB', 'bait name for a plex');
  $lims = st::api::lims->new(id_run => 7753, position => 1, tag_index=> 3);
  is($lims->bait_name, 'Human all exon 50MB',
    'bait name with white space around it');  
  $lims = st::api::lims->new(id_run => 7753, position => 1, tag_index=> 5);
  is($lims->bait_name, undef, 'all white space bait name');  
  $lims = st::api::lims->new(id_run => 7753, position => 2, tag_index=> 1);
  is($lims->bait_name, undef, 'no bait name');
  
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/samplesheet/4pool4libs_extended.csv';
  
  $lims = st::api::lims->new(id_run => 9999, position => 1);
  is($lims->bait_name, undef,
    'bait name undefined for a non-pool lane if there is no bait element');
  $lims = st::api::lims->new(id_run => 9999, position => 2);
  is($lims->bait_name,'Fox bait', 'bait name for a non-pool lane');
};

subtest 'Consent and separation of human data' => sub {
  plan tests => 17;

  my $schema_wh;
  lives_ok { $schema_wh = Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/])->new_object({})->create_test_db(
    q[WTSI::DNAP::Warehouse::Schema],q[t/data/fixtures_lims_wh_samplesheet]) 
  } 'ml_warehouse test db created';

  my $lims = st::api::lims->new(
    driver_type => 'ml_warehouse',
    mlwh_schema => $schema_wh,
    id_flowcell_lims => 13994,
    position => 1,
    tag_index => 4
  );
  is( $lims->sample_consent_withdrawn, 1, 'sample consent is withdrawn');

  $lims = st::api::lims->new(
    driver_type => 'ml_warehouse',
    mlwh_schema => $schema_wh,
    id_flowcell_lims => 13994,
    position => 1,
    tag_index => 5
  );
  is( $lims->sample_consent_withdrawn, 0, 'sample consent is not withdrawn');
  
  $lims = st::api::lims->new(
    driver_type => 'ml_warehouse',
    mlwh_schema => $schema_wh,
    id_flowcell_lims => 13994,
    position => 1,
  );
  ok( $lims->is_pool, 'lane is a pool');
  ok( $lims->contains_nonconsented_human, 'lane contains unconsented human');
  ok( $lims->separate_y_chromosome_data, 'Y chromosome should be separated');
  ok( $lims->contains_nonconsented_xahuman,
    'lane does contain nonconsented X and autosomal human');
 
  $lims = st::api::lims->new(
    driver_type => 'ml_warehouse',
    mlwh_schema => $schema_wh,
    id_flowcell_lims => 13994,
    position => 1,
    tag_index => 0 
  );
  ok( $lims->contains_nonconsented_human, 'tag0 contains unconsented human');
  ok( $lims->separate_y_chromosome_data, 'tag0 Y chromosome should be separated');
  ok( $lims->contains_nonconsented_xahuman,
    'tag0 does contain nonconsented X and autosomal human');

  $lims = st::api::lims->new(
    driver_type => 'ml_warehouse',
    mlwh_schema => $schema_wh,
    id_flowcell_lims => 13994
  );
  ok( !$lims->contains_nonconsented_human,
    'unconsented human flag does not propagate to the batch level');
  ok( !$lims->separate_y_chromosome_data,
    'Y chromosome separation flag does not propagate to the batch level');
  ok( !$lims->contains_nonconsented_xahuman,
    'nonconsented X and autosomal human flag does not propagate to the batch level');

  $lims = st::api::lims->new(
    driver_type => 'ml_warehouse',
    mlwh_schema => $schema_wh,
    id_flowcell_lims => 76873,
    position => 1,
  );
  ok( $lims->is_pool, 'lane is a pool');
  ok( !$lims->contains_nonconsented_human,
    'lane does not contain unconsented human');
  ok( !$lims->separate_y_chromosome_data, 'Y chromosome should not be separated');
  ok( !$lims->contains_nonconsented_xahuman,
    'lane does not contain nonconsented X and autosomal human');
};

subtest 'Library types' => sub {
  plan tests => 7;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/samplesheet/4pool4libs_extended.csv';
  
  my $lims = st::api::lims->new(id_run => 9999);
  is($lims->library_type, undef, 'library type undefined on a batch level');
  $lims = st::api::lims->new(id_run => 9999, position => 2); # non-pool lane
  is($lims->library_type, 'No PCR', 'library type');
  $lims = st::api::lims->new(id_run => 9999, position => 8);
  is($lims->library_type, undef, 'library type undefined for a pool');
  is(join(q[,], $lims->library_types), q[Pre-quality controlled],
    'library types');
  $lims = st::api::lims->new(id_run => 9999, position => 8, tag_index => 0);
  is($lims->library_type, undef, 'library type undefined for tag 0');
  $lims = st::api::lims->new(id_run => 9999, position => 8, tag_index => 88);
  is($lims->library_type, 'Pre-quality controlled', 'library type');
  $lims = st::api::lims->new(id_run => 9999, position => 8, tag_index => 168);
  is($lims->library_type, undef, 'library type is not specified');
};

1;
