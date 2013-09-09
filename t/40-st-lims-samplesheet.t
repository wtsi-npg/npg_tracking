use strict;
use warnings;
use Test::More tests => 108;
use Test::Exception;
use Test::Warn;
use Test::Deep;

use_ok('st::api::lims::samplesheet');

{
  my $path = 't/data/samplesheet/miseq_default.csv';

  my $ss = st::api::lims::samplesheet->new(id_run => 10262, path => $path);
  isa_ok ($ss, 'st::api::lims::samplesheet');
  is ($ss->is_pool, 0, 'is_pool false on run level');
  my @lanes;
  lives_ok {@lanes = $ss->children}  'can get lane-level objects';
  is ($lanes[0]->id_run, 10262, 'lane id_run as set');

  $ss = st::api::lims::samplesheet->new(id_run => 10000,path => $path,);
  warning_is { @lanes = $ss->children }
    q[Supplied id_run 10000 does not match Experiment Name, 10262],
    'warning when id_run and Experiment Name differ';
  is ($ss->id_run, 10000, 'run-level id_run as set, differs from Experiment Name');
  is ($lanes[0]->id_run, 10000, 'lane id_run as set, differs from Experiment Name');

  lives_ok {$ss = st::api::lims::samplesheet->new(path => $path,)}
   'can create object without id_run';
  is ($ss->id_run, undef, 'id_run undefined');
  is ($ss->is_pool, 0, 'is_pool false on run level');
  is ($ss->is_control, undef, 'is_control false on run level');
  is ($ss->library_id, undef, 'library_id undef on run level');
  is ($ss->library_name, undef, 'library_name undef on run level');
  warning_is { @lanes = $ss->children }
    q[id_run is set to Experiment Name, 10262],
    'warning when settign id_run from Experiment Name';
  is ($ss->id_run, 10262, 'id_run set from Experiment Name');
  is (scalar @lanes, 1, 'one lane returned');
  my $lane = $lanes[0];
  is ($lane->position, 1, 'position is 1');
  is ($lane->id_run, 10262, 'id_run set correctly from Experiment Name');
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
  is ($plexes[95]->position, 1, 'position of the last plex is 1');
  is ($plexes[95]->tag_index, 96, 'tag_index of the last plex is 96');
  is ($plexes[95]->id_run, 10262, 'id_run of the last plex set correctly from Experiment Name');
  is ($plexes[95]->default_tag_sequence, 'GTCTTGGC', 'tag sequence of the last plex');
  is ($plexes[95]->library_id, 7583506, 'library_id of the last plex');
  is ($plexes[95]->sample_name, 'LIA_96', 'sample_name of the last plex');
}

{
  my $path = 't/data/samplesheet/miseq_default.csv';
  throws_ok {st::api::lims::samplesheet->new(id_run => 10262, position =>2, path => $path)}
    qr/Position 2 not defined in t\/data\/samplesheet\/miseq_default\.csv/,
    'error instantiating an object for a non-existing lane';
 
  my $ss;
  lives_ok {$ss=st::api::lims::samplesheet->new(id_run => 10262, position =>1, path => $path)}
    'no error instantiating an object for an existing lane';
  is ($ss->position, 1, 'correct position');
  is ($ss->is_pool, 1, 'lane is a pool');
  is ($ss->library_id, undef, 'pool lane library_id undefined');
  is (scalar $ss->children, 96, '96 plexes returned');

  throws_ok {st::api::lims::samplesheet->new(id_run => 10262, position =>2, tag_index => 3, path => $path)}
    qr/Position 2 not defined in t\/data\/samplesheet\/miseq_default\.csv/,
    'error instantiating an object for a non-existing lane';
  throws_ok {st::api::lims::samplesheet->new(id_run => 10262, position =>1, tag_index => 303, path => $path)}
    qr/Tag index 303 not defined in t\/data\/samplesheet\/miseq_default\.csv/,
    'error instantiating an object for a non-existing tag index';

  lives_ok {$ss=st::api::lims::samplesheet->new(id_run => 10262, position =>1, tag_index => 3, path => $path)}
    'no error instantiation an object for an existing lane and plex';
  is ($ss->position, 1, 'correct position');
  is ($ss->tag_index, 3, 'correct tag_index');
  is ($ss->is_pool, 0, 'plex is not a pool');
  is ($ss->default_tag_sequence, 'TTAGGCAT', 'correct default tag sequence');
  is ($ss->library_id, 7583413, 'library id is correct');
  is ($ss->sample_name, 'LIA_3', 'sample name is correct');
  is (scalar $ss->children, 0, 'zero children returned');

  lives_ok {$ss=st::api::lims::samplesheet->new(id_run => 10262, position =>1, tag_index => 0, path => $path)}
    'no error instantiating an object for an existing lane and tag index 0';
  is (scalar $ss->children, 96, '96 children returned for tag zero');
  is ($ss->is_pool, 1, 'tag zero is a pool');
  is ($ss->library_id, undef, 'tag_zero library_id undefined');
  is ($ss->default_tag_sequence, undef, 'default tag sequence undefined');
}

{
  my $path = 't/data/samplesheet/miseq_extended.csv';
  my $ss;
  lives_ok {$ss=st::api::lims::samplesheet->new(id_run => 10262, position =>1, path => $path)}
    'no error instantiating an object for an existing lane';
  is ($ss->position, 1, 'correct position');
  is ($ss->is_pool, 1, 'lane is a pool');
  is ($ss->library_id, undef, 'pool lane library_id undefined');
  my @plexes = $ss->children;
  is (scalar @plexes, 6, '6 plexes returned');
  is (join(q[ ], map {$_->tag_index} @plexes), '3 4 11 12 22 23', 'children array sorted by tag_index');

  is ($plexes[0]->tag_index, 3, 'tag index for the first plex');
  is ($plexes[0]->default_tag_sequence, 'ATCACGTT', 'tag sequence for the first plex');
  is ($plexes[0]->is_control, undef, 'plex is not control');
  is ($plexes[0]->sample_name, 'library_1', 'plex sample name from the extended set rather than from Sample_Name');
  is ($plexes[0]->study_id, 55, 'plex study_id');
  is ($plexes[0]->sample_reference_genome, 'Enterococcus hirae (ATCC_9790)', 'sample ref genome');
  is ($plexes[0]->study_reference_genome, undef, 'study ref genome undefined');

  is ($plexes[1]->tag_index, 4, 'tag index for the first plex');
  is ($plexes[1]->default_tag_sequence, 'CGATGTTT', 'tag sequence for the first plex');
  is ($plexes[1]->is_control, 1, 'plex is control');
  is ($plexes[1]->sample_name, 'library_2', 'plex sample name from the extended set rather than from Sample_Name');
  is ($plexes[1]->study_id, 56, 'plex study_id');
  is ($plexes[1]->sample_reference_genome, undef, 'sample ref genome undefined');
  is ($plexes[1]->study_reference_genome, 'Rattus_norvegicus (Rnor_5.0)', 'study ref genome');
}

{
  my $path = 't/data/samplesheet/multilane.csv'; #extended MiSeq samplesheet
  my $ss = st::api::lims::samplesheet->new(id_run => 10262, path => $path);
  my @lanes = $ss->children;
  is (scalar @lanes, 5, '5 lanes parsed');
  is (join(q[ ], map {$_->position} @lanes), '1 2 3 4 5', 'children array sorted by position');

  my $lane = $lanes[0];
  is ($lane->is_pool, 1, 'lane 1 is a pool');
  is ($lane->is_control, undef, 'lane 1 is not control');

  $lane = $lanes[1];
  is ($lane->is_pool, 0, 'lane 2 is not a pool');
  is ($lane->is_control, undef, 'lane 2 is not control');
  is (scalar $lane->children, 0, 'no children for a library');
  is ($lane->library_id, 7583413, 'library id on lane level');
  is ($lane->study_id, 57, 'study id on lane level');

  $lane = $lanes[2];
  is ($lane->is_pool, 1, 'lane 3 is a pool');
  is ($lane->is_control, undef, 'lane 3 is not control');
  my @plexes = $lane->children;
  is (scalar @plexes, 2, 'two plexes for this lane');
  is ($lane->library_id, undef, 'library id on lane level is undefined');
  is ($lane->study_id, undef, 'study id on lane level is undefined');
  is ($plexes[0]->tag_index, 12, 'tag index of the first plex');
  is ($plexes[0]->library_id, 7583414, 'library id of the first plex');
  is ($plexes[0]->study_id, 57, 'study id of the first plex');

  $lane = $lanes[3];
  is ($lane->is_pool, 1, 'lane 4 is a pool');
  is ($lane->is_control, undef, 'lane 4 is not control');
  @plexes = $lane->children;
  is (scalar @plexes, 2, 'two plexes for this lane');
  is ($lane->library_id, undef, 'library id on lane level is undefined');
  is ($lane->study_id, undef, 'study id on lane level is undefined');
  is ($plexes[0]->tag_index, 12, 'tag index of the first plex');
  is ($plexes[1]->tag_index, 22, 'tag index of the second plex');
  is ($plexes[1]->library_id, 7583415, 'library id of the second plex');
  is ($plexes[1]->study_id, 58, 'study id of the second plex');

  $lane = $lanes[4];
  is ($lane->is_pool, 0, 'lane 5 is not a pool');
  is ($lane->is_control, 1, 'lane 5 is control');
}

1;