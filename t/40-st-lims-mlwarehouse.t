use strict;
use warnings;
use Test::More;
use Test::Exception;

my $driver_package = 'st::api::lims::ml_warehouse';
my $available = eval "require $driver_package";
if (!$available) {
  plan skip_all => "$driver_package is not deployed or cannot be loaded";
} else {
  plan tests => 6;

  use_ok('st::api::lims');

  my $schema_wh;
  lives_ok { $schema_wh = Moose::Meta::Class->create_anon_class(
    roles => [qw/npg_testing::db/])->new_object({})->create_test_db(
    q[WTSI::DNAP::Warehouse::Schema],q[t/data/fixtures_lims_wh]) 
  } 'ml_warehouse test db created';

  subtest 'family tree, product table entries are absent' => sub {
    plan tests => 11;

    my @lanes = st::api::lims->new(
               id_flowcell_lims => 5992,
               driver_type      => 'ml_warehouse',
               mlwh_schema      => $schema_wh)->children();
    is(scalar @lanes, 1, 'one lane only');
    my $lane = $lanes[0];
    ok(!$lane->is_pool, 'lane is not a pool');
    is($lane->id_run, undef, 'no product data are linked');
    is($lane->qc_state, undef, 'qc state is undefined');

    @lanes = st::api::lims->new(
               id_flowcell_lims => 35053,
               driver_type      => 'ml_warehouse',
               mlwh_schema      => $schema_wh)->children();
    is(scalar @lanes, 1, 'one lane only');
    $lane = $lanes[0];
    ok($lane->is_pool, 'lane is a pool');
    is($lane->id_run, 15454, 'product data are linked');
    is($lane->qc_state, undef, 'pool qc state is undefined');
    my @plexes = $lane->children;
    my $plex = $plexes[0];
    is($plex->tag_index, 26, 'tag index');
    is($plex->id_run, 15454, 'id_run is propagated');
    is($plex->qc_state, undef, 'qc state undefined');
  };

  subtest 'family tree, product table entries are present' => sub {
    plan tests => 33;
    
    my $id_run = 15440;
    my $l = st::api::lims->new(
               id_flowcell_lims => 34769,
               driver_type      => 'ml_warehouse',
               mlwh_schema      => $schema_wh);
    is($l->id_run, $id_run, 'id_run is propagated');
    is($l->qc_state, undef, 'flowcell qc state undefined');

    my @lanes = $l->children();
    is(scalar @lanes, 2, 'two lanes');
    my $count = 1;
    for my $lane (@lanes) {
      ok($lane->is_pool, 'lane is a pool');
      is($lane->position, $count, "position is $count");
      is($lane->id_run, $id_run, 'id_run is propagated');
      is($lane->qc_state, undef, 'pool qc state undefined');
      my @plexes = $lane->children();
      my $plex = $plexes[0];
      my $tag_index = 81;
      ok(!$plex->is_pool, 'plex is not a pool');
      is($plex->tag_index, $tag_index, "tag index is $tag_index");
      is($plex->position, $count, "plex position is $count");
      is($plex->id_run, $id_run, 'id_run is propagated');
      is($plex->gbs_plex_name, undef, 'gbs_plex_name is undefined');
      is($plex->primer_panel, undef, 'primer_panel is undefined');

      is(join(q[ ],
        map {join q[:], $_->tag_index, defined $_->qc_state ? $_->qc_state : q[undef]}
             @plexes),
        $count == 1 ? '81:1 82:undef 83:undef 84:0 168:undef' :
                      '81:undef 82:undef 83:undef 84:undef 168:undef',
        'qc state per plex');    
      ok(!$plex->children(), 'no children');
      $count++;
    }
    
    for my $position ((1, 2)) {
      my $qc_value = $position - 1;
      $schema_wh->resultset('IseqProductMetric')
                ->search({'id_run' => $id_run, 'position' => $position})
                ->update({'qc' => $qc_value});
      my $lane = st::api::lims->new(
               id_flowcell_lims => 34769,
               position         => $position,
               driver_type      => 'ml_warehouse',
               mlwh_schema      => $schema_wh);
      is(join(q[ ], map {join q[:],$_->tag_index,$_->qc_state} $lane->children),
        "81:${qc_value} 82:${qc_value} 83:${qc_value} 84:${qc_value} 168:${qc_value}",
        'qc state per plex');
      is($lane->qc_state, $qc_value, 'distinct across plexes qc value');

      my $plex = st::api::lims->new(
               id_flowcell_lims => 34769,
               position         => $position,
               tag_index        => 83,
               driver_type      => 'ml_warehouse',
               mlwh_schema      => $schema_wh);
      is($plex->qc_state, $qc_value,
        'qc state for directly constructed plex-level object');
    }
  };

  subtest 'gbs plex name, primer panel' => sub {
    plan tests => 13;

    my $id_run = 24135;
    my $l= st::api::lims->new(
              id_flowcell_lims => 57543,
              driver_type      => 'ml_warehouse',
              mlwh_schema      => $schema_wh);
    is($l->id_run, $id_run, 'id_run is propagated');

    is($l->gbs_plex_name, undef, 'gbs_plex_name undefined on a batch level');
    is($l->primer_panel, undef, 'primer_panel undefined on a batch level');

    $l = st::api::lims->new(id_flowcell_lims => 57543, position => 1, 
                            driver_type => 'ml_warehouse', mlwh_schema => $schema_wh);
    is($l->gbs_plex_name, undef, 'gbs_plex_name undefined on a pool level as mixed');
    is($l->primer_panel, undef, 'primer_panel undefined on a pool level as mixed');
    
    $l = st::api::lims->new(id_flowcell_lims => 57543, position => 1, tag_index=> 1, 
                               driver_type => 'ml_warehouse', mlwh_schema => $schema_wh);
    is($l->gbs_plex_name, 'Hs_MajorQC', 'gbs_plex_name for a plex');
    is($l->primer_panel, 'Hs_MajorQC', 'primer_panel for a plex');

    $l = st::api::lims->new(id_flowcell_lims => 57543, position => 1, tag_index=> 2, 
                            driver_type => 'ml_warehouse', mlwh_schema => $schema_wh);
    is($l->gbs_plex_name, 'Pf_GRC1', 'gbs_plex_name for another plex');
    is($l->primer_panel, 'Pf_GRC1', 'primer_panel for another plex');

    $l = st::api::lims->new(id_flowcell_lims => 57543, position => 1, tag_index=> 3,
                               driver_type => 'ml_warehouse', mlwh_schema => $schema_wh);
    is($l->gbs_plex_name, 'Pf_GRC2', 'gbs_plex_name for yet another plex');
    is($l->primer_panel, 'Pf_GRC2', 'primer_panel for yet another plex');

    $l = st::api::lims->new(id_flowcell_lims => 57543, position => 1, tag_index=> 4,
                             driver_type => 'ml_warehouse', mlwh_schema => $schema_wh);
    is($l->gbs_plex_name, undef, 'gbs_plex_name undefined');
    is($l->primer_panel, undef, 'primer_panel undefined');
  };

  subtest 'sample controls' => sub {
    plan tests => 6;

    my $init = {id_flowcell_lims => 57543, position => 1,
                driver_type => 'ml_warehouse', mlwh_schema => $schema_wh};

    for my $ti ((1,2,3)) {
      $init->{tag_index} = $ti;
      my $l = st::api::lims->new($init);
      if ($ti <= 2 ) {
        ok($l->sample_is_control, 'sample is control');
        my $ctype = ($ti == 1) ? 'negative' : 'positive';
        is($l->sample_control_type, $ctype, 'correct control type');
      } else {
        ok(!$l->sample_is_control, 'sample is not control');
        is($l->sample_control_type, undef, 'sample control type is undefined');
      }
    }
  };
}

1;
