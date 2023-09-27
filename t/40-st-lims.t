use strict;
use warnings;
use Test::More tests => 15;
use Test::Exception;
use Test::Warn;
use File::Temp qw/ tempdir /;

my $num_delegated_methods = 48;

local $ENV{'http_proxy'} = 'http://wibble.com';

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
  plan tests => 23;

  my @other = qw/batch_id id_flowcell_lims flowcell_barcode/;
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

subtest 'Lane-level object via samplesheet driver' => sub {
  plan tests => 14;

  my $path = 't/data/samplesheet/miseq_default.csv';
  lives_ok {st::api::lims->new(id_run => 10262, position =>2, path => $path, driver_type => 'samplesheet')}
    'no error instantiation an object for a non-existing lane';
  throws_ok {st::api::lims->new(id_run => 10262, position =>2, path => $path, driver_type => 'samplesheet')->library_id}
    qr/Position 2 not defined in/, 'error invoking a driver method on an object for a non-existing lane';
  lives_ok {st::api::lims->new(id_run => 10262, position =>2, driver_type => 'samplesheet')}
    'no error instantiation an object without path';

  my $ss=st::api::lims->new(id_run => 10262, position =>1, tag_index => 0, path => $path);
  is (scalar $ss->children, 96, '96 children returned for tag zero');
  is ($ss->is_pool, 1, 'tag zero is a pool');
  is ($ss->library_id, undef, 'tag_zero library_id undefined');
  is ($ss->default_tag_sequence, undef, 'default tag sequence undefined');
  is ($ss->tag_sequence, undef, 'tag sequence undefined');
  is ($ss->purpose, undef, 'purpose');

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = $path;
  $ss=st::api::lims->new(id_run => 10262, position =>1);
  is ($ss->path, $path, 'samplesheet path captured from NPG_CACHED_SAMPLESHEET_FILE') or diag explain $ss;
  is ($ss->position, 1, 'correct position');
  is ($ss->is_pool, 1, 'lane is a pool');
  is ($ss->library_id, undef, 'pool lane library_id undefined');
  is (scalar $ss->children, 96, '96 plexes returned');
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

subtest 'Creating tag zero object' => sub {
  plan tests => 4;

  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/test40_lims/samplesheet_novaseq4lanes.csv';

  my $l = st::api::lims->new(id_run => 25846);
  throws_ok { $l->create_tag_zero_object() } qr/Position should be defined/,
    'method cannot be called on run-level object';
  $l = st::api::lims->new(rpt_list => '25846:2:1');
  throws_ok { $l->create_tag_zero_object() } qr/Position should be defined/,
    'method cannot be called on an object for a composition';

  my $description = 'st::api::lims object, driver - samplesheet, id_run 25846, ' .
    'path t/data/test40_lims/samplesheet_novaseq4lanes.csv, position 3, tag_index 0';
  $l = st::api::lims->new(id_run => 25846, position => 3);
  is ($l->create_tag_zero_object()->to_string(), $description, 'created from lane-level object');
  $l = st::api::lims->new(id_run => 25846, position => 3, tag_index => 5);
  is ($l->create_tag_zero_object()->to_string(), $description, 'created from plex-level object');
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
  plan tests => 14;

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
  
  $lims = st::api::lims->new(id_run => 9999, position => 7, tag_index => 77);
  $insert_size = $lims->required_insert_size;
  is (keys %{$insert_size}, 1, 'one entry in the insert size hash');
  is ($insert_size->{$id}->{q[from]}, 100, 'required FROM insert size');
  is ($insert_size->{$id}->{q[to]}, 1000, 'required TO insert size');
};

1;
