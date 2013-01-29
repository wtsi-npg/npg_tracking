# Id:            $Id: 14-dbic-RunStatusDict.t 14068 2011-08-26 10:24:09Z ajb $
use strict;
use warnings;
use English qw(-no_match_vars);

use Test::More tests => 38;
use Test::Deep;
use Test::Exception::LessClever;
use Test::MockModule;
use DateTime;

use lib q{t};
use t::dbic_util;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 15060 $ =~ /(\d+)/msx; $r; };

Readonly::Scalar my $ABSURD_ID => 100_000_000;

use_ok( q{npg_tracking::Schema::Result::RunLaneStatus} );


my $schema = t::dbic_util->new->test_schema();
my $test;

lives_ok { $test = $schema->resultset( q{RunLaneStatus} )->new({}) } q{Create test object};

isa_ok( $test, q{npg_tracking::Schema::Result::RunLaneStatus}, q{$test} );

my $rs;
lives_ok {
  $rs = $schema->resultset( q{RunLaneStatus} )->search({
    id_run_lane_status => 1,
  });
} q{obtain a result set ok};

isa_ok( $rs, q{DBIx::Class::ResultSet}, q{$rs} );

my $row = $rs->next();

is( $row->id_run_lane(), 1, q{id_run_lane obtained correctly} );

is( $row->description(), q{analysis in progress}, q{description is correct} );

is( $row->id_run(), 1, q{id_run is correct} );

is( $row->position(), 7, q{position is correct} );

my $row2;
throws_ok {
  $row2 = $row->update_run_lane_status( {} );
} qr{No[ ]description[ ]provided}, q{update a run_lane status - fail no description};
throws_ok {
  $row2 = $row->update_run_lane_status( {
    description => q{analysis complete},
  } );
} qr{No[ ]lane[ ]information[ ]provided}, q{update a run_lane status - fail no run lane info};
throws_ok {
  $row2 = $row->update_run_lane_status( {
    description => q{analysis complete},
    id_run_lane => 1,
  } );
} qr{no[ ]user[ ]provided}, q{update a run_lane status - fail no user - has id_run_lane};
throws_ok {
  $row2 = $row->update_run_lane_status( {
    description => q{analysis complete},
    id_run => 1,
  } );
} qr{No[ ]lane[ ]information[ ]provided}, q{update a run_lane status - fail no run lane info - has id_run};
throws_ok {
  $row2 = $row->update_run_lane_status( {
    description => q{analysis complete},
    id_run => 1,
    position => 7,
  } );
} qr{no[ ]user[ ]provided}, q{update a run_lane status - fail no user - has id_run and position};

lives_ok {
  $row2 = $row->update_run_lane_status( {
    description => q{analysis complete},
    id_run => 1,
    position => 7,
    username => q{joe_annotator},
  } );
} q{update a run_lane status - success};
cmp_ok( $schema->resultset( q{RunLane} )->find({id_run => 1, position => 7})->related_resultset(q(run_lane_statuses))->count, q(==), 2, 'check run lane 7 statuses');
cmp_ok( $schema->resultset( q{RunLane} )->find({id_run => 1, position => 7})->related_resultset(q(run_lane_statuses))->search({iscurrent => 1})->count, q(==), 1, 'check run lane 7 current statuses');

diag $row2;
my $retrieved_row;
lives_ok {
  $retrieved_row = $schema->resultset( q{RunLaneStatus} )->search({
    id_run_lane_status => 2,
  })->first();
} q{obtain saved result set ok};
is( $retrieved_row->id_run_lane_status(), 2, q{id_run_lane_status assigned} );
is( $retrieved_row->description(), q{analysis complete}, q{description saved correctly} );
is( $retrieved_row->user->username(), q{joe_annotator}, q{user saved correctly} );
is( $retrieved_row->iscurrent(), 1, q{saved row iscurrent} );
note q().DateTime->now();
is( $retrieved_row->date()->ymd(), DateTime->now()->ymd(), q{date is the same as todays date - if this fails, it might be because it thinks it is around midnight} ); # note, this test may fail if you run around midnight
lives_ok {
  $retrieved_row = $schema->resultset( q{RunLaneStatus} )->search({
    id_run_lane_status => 1,
  })->first();
} q{obtain updated result set ok};
is( $retrieved_row->iscurrent(), 0, q{updated row noncurrent} );
isnt( $schema->resultset( q{Run} )->find(1)->current_run_status_description(), q{qc review pending}, q{run has not had it's status updated to 'qc review pending'} );
lives_ok {
  $row2 = $row->update_run_lane_status( {
    description => q{analysis complete},
    id_run => 1,
    position => 8,
    username => q{joe_annotator},
  } );
} q{update a run_lane status - success};
is( $schema->resultset( q{Run} )->find(1)->current_run_status_description(), q{qc review pending}, q{run has had it's status updated to 'qc review pending'} );

lives_ok {
  $row2 = $row->update_run_lane_status( {
    description => q{analysis in progress},
    id_run => 1,
    position => 7,
    username => q{joe_annotator},
  } );
} q{update a run_lane status as analysis in progress - success};
cmp_ok( $schema->resultset( q{RunLane} )->find({id_run => 1, position => 7})->related_resultset(q(run_lane_statuses))->count, q(==), 3, 'check run lane 7 statuses');
cmp_ok( $schema->resultset( q{RunLane} )->find({id_run => 1, position => 7})->related_resultset(q(run_lane_statuses))->search({iscurrent => 1})->count, q(==), 1, 'check run lane 7 current statuses');
is( $schema->resultset( q{Run} )->find(1)->current_run_status_description(), q{qc review pending}, q{run has not had it's status updated} );

lives_ok {
  $row2 = $row->update_run_lane_status( {
    description => q{manual qc complete},
    id_run => 1,
    position => 7,
    username => q{joe_annotator},
  } );
} q{update a run_lane status as manual qc complete - success};
isnt( $schema->resultset( q{Run} )->find(1)->current_run_status_description(), q{archival pending}, q{run has not had it's status updated to 'archival pending'} );
lives_ok {
  $row2 = $row->update_run_lane_status( {
    description => q{manual qc complete},
    id_run => 1,
    position => 8,
    username => q{joe_annotator},
  } );
} q{update a run_lane status as manual qc complete - success};
cmp_ok( $schema->resultset( q{RunLane} )->find({id_run => 1, position => 7})->related_resultset(q(run_lane_statuses))->count, q(==), 4, 'check run lane 7 statuses');
cmp_ok( $schema->resultset( q{RunLane} )->find({id_run => 1, position => 7})->related_resultset(q(run_lane_statuses))->search({iscurrent => 1})->count, q(==), 1, 'check run lane 7 current statuses');
diag $schema->resultset( q{RunLane} )->search({id_run => 1})->count().' lanes for run 1';
diag $schema->resultset( q{RunLane} )->search({id_run => 1})->search_related(q(run_lane_statuses),{iscurrent => 1, q(run_lane_status_dict.description) => q(manual qc complete)}, {join=>q(run_lane_status_dict)})->count().' current manual qc complete lanes for run 1';
is( $schema->resultset( q{Run} )->find(1)->current_run_status_description(), q{archival pending}, q{run has had it's status updated to 'archival pending'} );
1;
