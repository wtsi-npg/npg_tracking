use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;
use Test::Warn;
use File::Slurp;
use File::Temp qw(tempdir);

use_ok('st::api::lims::samplesheet');

my $temp_dir = tempdir(CLEANUP => 1);

sub _lane_hash {
  my ($lane_l, @methods) = @_;

  my $h = {};
  foreach my $plex ($lane_l->is_pool ? $lane_l->children : ($lane_l)) {
    my $tag_h = {};
    foreach my $method (@methods) {
      my $value = $plex->$method;
      if (defined $value) {
        if ($value eq '0' || $value eq q[]) {
          $value = undef;
        }
      }
      $tag_h->{$method} = $value;
    }
    if ($lane_l->is_pool) {
      $h->{$plex->tag_index} = $tag_h;
    } else {
      $h = $tag_h;
    }
  }
  return $h; 
}

subtest 'MiSeq run, default samplesheet, run-level object' => sub {
  plan tests => 40;

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
  my $is_pool;
  warning_is { $is_pool = $ss->is_pool }
    q[id_run is set to Experiment Name, 10262],
    'warning when setting id_run from Experiment Name';
  is ($is_pool, 0, 'is_pool false on run level');
  is ($ss->id_run, 10262, 'id_run set from Experiment Name');
  is ($ss->is_control, undef, 'is_control false on run level');
  is ($ss->library_id, undef, 'library_id undef on run level');
  is ($ss->library_name, undef, 'library_name undef on run level');
  @lanes = $ss->children;
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
  is ($plexes[0]->default_tagtwo_sequence, undef, 'second index undefined');
  is ($plexes[95]->position, 1, 'position of the last plex is 1');
  is ($plexes[95]->tag_index, 96, 'tag_index of the last plex is 96');
  is ($plexes[95]->id_run, 10262, 'id_run of the last plex set correctly from Experiment Name');
  is ($plexes[95]->default_tag_sequence, 'GTCTTGGC', 'tag sequence of the last plex');
  is ($plexes[95]->default_tagtwo_sequence, undef, 'second index undefined');
  is ($plexes[95]->library_id, 7583506, 'library_id of the last plex');
  is ($plexes[95]->sample_name, 'LIA_96', 'sample_name of the last plex');
};

subtest 'MiSeq run, default samplesheet, plex-level object' => sub {
  plan tests => 22;

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
  is ($ss->default_tagtwo_sequence, undef, 'second tag sequence undefined');
};

subtest 'MiSeq run, extended samplesheet' => sub {
  plan tests => 28;

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
  is ($plexes[0]->default_tagtwo_sequence, undef, 'default tag sequence undefined');
  is ($plexes[0]->is_control, 0, 'plex is not control');
  is ($plexes[0]->sample_name, 'library_1', 'plex sample name from the extended set rather than from Sample_Name');
  is ($plexes[0]->study_id, 55, 'plex study_id');
  is ($plexes[0]->sample_reference_genome, 'Enterococcus hirae (ATCC_9790)', 'sample ref genome');
  is ($plexes[0]->study_reference_genome, undef, 'study ref genome undefined');
  is ($plexes[0]->sample_supplier_name, 'sample_3', 'supplier sample name');
  is ($plexes[0]->sample_cohort, 'plan3', 'sample cohort');
  is ($plexes[0]->sample_donor_id, 'donor3', 'sample donor id');

  is ($plexes[1]->tag_index, 4, 'tag index for the first plex');
  is ($plexes[1]->default_tag_sequence, 'CGATGTTT', 'tag sequence for the first plex');
  is ($plexes[1]->default_tagtwo_sequence, undef, 'default tag sequence undefined');
  is ($plexes[1]->is_control, 1, 'plex is control');
  is ($plexes[1]->sample_name, 'library_2', 'plex sample name from the extended set rather than from Sample_Name');
  is ($plexes[1]->study_id, 56, 'plex study_id');
  is ($plexes[1]->sample_reference_genome, undef, 'sample ref genome undefined');
  is ($plexes[1]->study_reference_genome, 'Rattus_norvegicus (Rnor_5.0)', 'study ref genome');
  is ($plexes[1]->sample_supplier_name, 'sample_4', 'supplier sample name');
  is ($plexes[1]->sample_cohort, 'plan4', 'sample cohort');
  is ($plexes[1]->sample_donor_id, 'donor4', 'sample donor id');
};

my $test1 = sub {
  my $ss = shift;
  my @lanes = $ss->children;
  is (scalar @lanes, 5, '5 lanes parsed');
  is (join(q[ ], map {$_->position} @lanes), '1 2 3 4 5', 'children array sorted by position');

  my $lane = $lanes[0];
  is ($lane->is_pool, 1, 'lane 1 is a pool');
  is ($lane->is_control, undef, 'lane 1 is not control');

  $lane = $lanes[1];
  is ($lane->is_pool, 0, 'lane 2 is not a pool');
  is ($lane->is_control, 0, 'lane 2 is not control');
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
};

subtest 'Multiple lanes, extended samplesheet' => sub {
  plan tests => 28;

  my $path = 't/data/samplesheet/multilane.csv'; #extended samplesheet
  my $ss = st::api::lims::samplesheet->new(id_run => 10262, path => $path);
  $test1->($ss);
};

subtest 'Multiple lanes, extended samplesheet with the id_run column' => sub {
  plan tests => 29;

  my @lines = read_file('t/data/samplesheet/multilane.csv');

  my $write_edited_file = sub {
    my ($path, $missing) = @_;
    my $count = 0;
    my @new_lines = ();
    foreach my $line (@lines) {
      $line =~ s{\s+\Z}{};
      $count == 0 and push @new_lines, $line . q[,];
      $count == 1 and push @new_lines, $line . q[id_run,];
      my $id_run = ($missing and ($count % 2 == 0)) ? q[] : 10262;
      $count > 1  and push @new_lines, $line . $id_run . q[,];
      $count++;
    }  
    write_file($path, map { $_ . qq[\n]} @new_lines);
  };

  my $path = join q[/], $temp_dir, 'multilane.csv';

  $write_edited_file->($path, 1);
  throws_ok {
    st::api::lims::samplesheet->new(id_run => 10262, path => $path)->children()
  } qr/No value in the id_run column/, 'error with id_run column partially filled';

  $write_edited_file->($path);
  $test1->(st::api::lims::samplesheet->new(id_run => 10262, path => $path));
};

subtest 'Multiple MiSeq runs' => sub {
  plan tests => 11;

  my @lines = read_file('t/data/samplesheet/6946_extended.csv');
  my $write_edited_file = sub {
    my ($path, $missing) = @_;
    my $count = 0;
    my @new_lines = ();
    foreach my $line (@lines) {
      $line =~ s{\s+\Z}{};
      $count == 0 and push @new_lines, $line . q[,];
      $count == 1 and push @new_lines, $line . q[id_run,];
      my $id_run = ($count % 2 == 0) ? 6946 : 6945;
      $count > 1  and push @new_lines, $line . $id_run . q[,];
      $count++;
    } 
    write_file($path, map { $_ . qq[\n]} @new_lines);
  };

  my $path = join q[/], $temp_dir, 'multiruns.csv';
  $write_edited_file->($path);

  my $err = "Samplesheet $path with data for multiple runs,";
  my $ss = st::api::lims::samplesheet->new(path => $path);
  throws_ok { $ss->children }
    qr/id_run column is present in a samplesheet, id_run attribute should be set/,
    'error if id_run attr is not set';
  $ss = st::api::lims::samplesheet->new(id_run => 6946, path => $path);
  throws_ok { $ss->children }
    qr/$err position attribute should be set/,
    'error if id_run attr is not set';
  throws_ok { st::api::lims::samplesheet->new(
              id_run => 6946, position => 1, tag_index => 0, path => $path) }
    qr/$err not possible to get data for tag zero/, 'error for tag zero';
  throws_ok { st::api::lims::samplesheet->new(
              id_run => 6946, position => 1, path => $path) }
    qr/$err pool data not available/, 'error for a pool';

  throws_ok { st::api::lims::samplesheet->new(
    id_run => 6946, position => 2, tag_index => 2, path => $path)
  } qr/Position 2 not defined in $path/,
    'error for position that does not exist';
  throws_ok { st::api::lims::samplesheet->new(
    id_run => 6946, position => 1, tag_index => 2, path => $path)
  } qr/Tag index 2 not defined in $path/,
    'error for position that does not exist';  
  
  lives_ok { $ss = st::api::lims::samplesheet->new(
    id_run => 6946, position => 1, tag_index => 1, path => $path);
  } 'no error, record exists';
  ok(!$ss->is_pool, 'not a pool');
  ok(!$ss->children, 'no children');
  is($ss->default_tag_sequence, 'ATCACGTT', 'correct tag sequence');
  
  $ss = st::api::lims::samplesheet->new(
    id_run => 6945, position => 1, tag_index => 2, path => $path);
  is($ss->default_tag_sequence, 'CGATGTTT', 'correct tag sequence');
};

subtest 'Multiple NovaSeq runs - top-up merge support' => sub {
  plan tests => 20;

  my $path = 't/data/samplesheet/novaseq_multirun.csv';
  my @components = ([26480,1,9],[26480,2,9],[26480,3,9],[26480,4,9],[28780,2,4]);
  foreach my $c (@components) {
    my $ss = st::api::lims::samplesheet->new(
                 id_run    => $c->[0],
                 position  => $c->[1],
                 tag_index => $c->[2],
                 path      => $path);
    is($ss->default_tag_sequence, 'AGTTCAGG', 'tag sequence');
    is($ss->default_tagtwo_sequence, 'CCAACAGA', 'tag2 sequence');
    is($ss->default_library_type, 'HiSeqX PCR free', 'library type');
    is($ss->sample_name, '7592352', 'sample name');
  }
};

subtest 'multiple lanes' => sub {
  plan tests => 5;

  my $path = 't/data/samplesheet/4pool4libs_extended.csv';
  my @ss_lanes = st::api::lims::samplesheet->new(id_run => 6946, path => $path)->children;
  ok(!$ss_lanes[0]->is_pool, 'lane 1 is a not pool');
  ok($ss_lanes[6]->is_pool, 'lane 7 is a pool');
  my @plexes = $ss_lanes[6]->children;
  my @spiked = grep {$_->spiked_phix_tag_index == 168} $ss_lanes[6]->children;
  is (scalar @spiked, scalar @plexes, 'spiked_phix_tag_index is set on plex level');
  is ($spiked[0]->default_tagtwo_sequence, undef, 'default tag sequence undefined');
  my $tag_zero = st::api::lims::samplesheet->new(id_run => 6946, position => 7, tag_index => 0, path => $path);
  is ($tag_zero->spiked_phix_tag_index, 168, 'spiked_phix_tag_index is set for tag zero');
};

subtest 'dual index extended' => sub {
  plan tests => 11;

  my $path = 't/data/samplesheet/dual_index_extended.csv';
  my $ss = st::api::lims::samplesheet->new(id_run => 6946, path => $path);
  my @lanes = $ss->children;
  is (scalar @lanes, 2, 'two lanes');
  my @plexes = $lanes[0]->children;
  is (scalar @plexes, 3, 'three samples in lane 1');
  my $plex = $plexes[0];
  is($plex->default_tag_sequence, 'CGATGTTT', 'first index');
  is($plex->default_tagtwo_sequence, 'AAAAAAAA', 'second index');
  $plex = $plexes[2];
  is($plex->default_tag_sequence, 'TGACCACT', 'first index');
  is($plex->default_tagtwo_sequence, 'AAAAAAAA', 'second index');
  @plexes = $lanes[1]->children;
  is (scalar @plexes, 3, 'three samples in lane 2');
  $plex = $plexes[0];
  is($plex->default_tag_sequence, 'GCTAACTC', 'first index');
  is($plex->default_tagtwo_sequence, 'GGGGGGGG', 'second index');
  $plex = $plexes[2];
  is($plex->default_tag_sequence, 'GTCTTGGC', 'first index');
  is($plex->default_tagtwo_sequence, 'GGGGGGGG', 'second index');
};

subtest 'dual index default' => sub {
  plan tests => 8;

  my $path = 't/data/samplesheet/miseq_default_dual_index.csv';
  my $ss = st::api::lims::samplesheet->new(id_run => 10262, position => 1, path => $path);
  is ($ss->is_pool, 1, 'lane 1 is a pool');
  my $plexes = {};
  map { $plexes->{$_->tag_index} = $_ } $ss->children;
  is(scalar keys %{$plexes}, 12, '12 plexes retrieved');
  my $p = $plexes->{1};
  is($p->default_tag_sequence, 'ATCACGTT', 'first index');
  is($p->default_tagtwo_sequence, 'GCCAATGT', 'second index');
  $p = $plexes->{2};
  is($p->default_tag_sequence, 'CGATGTTT', 'first index');
  is($p->default_tagtwo_sequence, 'ACTTGATG', 'second index');
  $p = $plexes->{9};
  is($p->default_tag_sequence, 'GATCAGCG', 'first index');
  is($p->default_tagtwo_sequence, undef, 'no second index');
};

1;
