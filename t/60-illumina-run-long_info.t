use strict;
use warnings;
use Test::More tests => 59;
use Test::Exception;
use Test::Deep;
use File::Temp qw(tempdir);
use Cwd;
use Carp;

BEGIN {
  local $ENV{'HOME'} = getcwd() . '/t';
  use_ok(q{npg_tracking::illumina::run::long_info});

  # package creation within BEGIN block to ensure after HOME is reset
  package test::long_info;
  use Moose;
  with qw{npg_tracking::illumina::run::short_info npg_tracking::illumina::run::folder};
  with qw{npg_tracking::illumina::run::long_info};
  no Moose;
  1;
}

package main;

my $basedir = tempdir( CLEANUP => 1 );
$ENV{dev} = qw{non_existant_dev_enviroment}; #prevent pickup of user's config
$ENV{TEST_DIR} = $basedir; #so when npg_tracking::illumina::run::folder globs the test directory

my $id_run = q{1234};
my $name = q{IL2_1234};
my $run_folder = q{123456_IL2_1234};
my $runfolder_path = qq{$basedir/nfs/sf44/IL2/analysis/123456_IL2_1234};
my $data_subpath = $runfolder_path . q{/Data};
my $intensities_subpath = $data_subpath . q{/Intensities};
my $basecalls_subpath = $intensities_subpath . q{/BaseCalls};
my $bustard_subpath = $intensities_subpath . q{/Bustard-2009-10-01};
my $gerald_subpath = $bustard_subpath . q{/GERALD-2009-10-01};
my $archive_subpath = $gerald_subpath . q{/archive};
my $qc_subpath = $archive_subpath . q{/qc};
my $config_path = $runfolder_path . q{/Config};

sub delete_staging {
  `rm -rf $basedir/nfs`;
  return 1;
}

sub create_staging {
  delete_staging();
  `mkdir -p $qc_subpath`;
  `mkdir $basecalls_subpath`;
  `mkdir $config_path`;
  `cp t/data/long_info/Recipe_GA2-PEM_MP_2x76Cycle+8_v7.7.xml $runfolder_path/`;
  `cp t/data/long_info/TileLayout.xml $config_path/`;
  return 1;
}

sub create_latest_summary_link {
  create_staging();
  `ln -s $gerald_subpath $runfolder_path/Latest_Summary`;
  return 1;
}

my $orig_dir = getcwd();

{
  my $long_info;
  lives_ok  { $long_info = test::long_info->new({id_run => 1234}); } q{created role_test object ok};

  create_staging();

  is($long_info->use_bases(), q{Y76,I8,y76}, q{use_bases string is correct});
  lives_ok  { $long_info = test::long_info->new({id_run => 1234}); } q{created role_test object ok};
  is($long_info->read_config_string(), q{Y76,I8,y76}, q{read_config_string returns same as use_bases});

  lives_ok  { $long_info = test::long_info->new({id_run => 1234}); } q{created role_test object ok};
  is($long_info->is_paired_read(), 1, q{Read is paired});
  lives_ok  { $long_info = test::long_info->new({id_run => 1234}); } q{created role_test object ok};
  is($long_info->is_indexed(), 1, q{Read is indexed});

  lives_ok  { $long_info = test::long_info->new({id_run => 1234}); } q{created role_test object ok};
  is($long_info->lane_count(), 8, q{correct number of lanes});

  lives_ok  { $long_info = test::long_info->new({id_run => 1234}); } q{created role_test object ok};
  is($long_info->expected_cycle_count(), 160, q{correct number of expected cycles});
  lives_ok  { $long_info = test::long_info->new({id_run => 1234}); } q{created role_test object ok};
  is($long_info->cycle_count(), 160, q{cycle count returns the same as expected_cycle_count});

  lives_ok  { $long_info = test::long_info->new({id_run => 1234}); } q{created role_test object ok};
  is($long_info->tilelayout_columns(), 2, q{correct number of tilelayout_columns});
  lives_ok  { $long_info = test::long_info->new({id_run => 1234}); } q{created role_test object ok};
  is($long_info->tilelayout_rows(), 60, q{correct number of tilelayout_rows});
  lives_ok  { $long_info = test::long_info->new({id_run => 1234}); } q{created role_test object ok};
  is($long_info->tile_count(), 120, q{correct number of tiles});

  lives_ok  { $long_info = test::long_info->new({id_run => 1234}); } q{created role_test object ok};
  is($long_info->is_rta(), 1, q{run is rta});
}

chdir $orig_dir; #need to leave directories before you can delete them....
eval { delete_staging(); } or do { carp 'unable to delete staging area'; };

#Now let's test a new HiSeq directory....
$ENV{TEST_DIR} = 't/data/long_info';
{
  my $long_info;
  lives_ok  { $long_info = test::long_info->new({id_run => 5281}); } q{created role_test (HiSeq run 5281, RunInfo.xml) object ok};
  cmp_ok($long_info->tile_count, '==', 32, 'correct tile count');
  lives_ok  { $long_info = test::long_info->new({id_run => 5281}); } q{created role_test (HiSeq run 5281, RunInfo.xml) object ok};
  cmp_ok($long_info->lane_count, '==', 8, 'correct lane count');
  lives_ok  { $long_info = test::long_info->new({id_run => 5281}); } q{created role_test (HiSeq run 5281, RunInfo.xml) object ok};
  cmp_ok($long_info->cycle_count, '==', 200, 'correct cycle count');
  lives_ok  { $long_info = test::long_info->new({id_run => 5281}); } q{created role_test (HiSeq run 5281, RunInfo.xml) object ok};
  cmp_ok($long_info->use_bases, 'eq', 'Y100,y100', 'correct use_bases string');
note($long_info->runfolder_path);

  lives_ok  { $long_info = test::long_info->new({id_run => 5281}); } q{created role_test (HiSeq run 5281, RunInfo.xml) object ok};
  my $test_lane_tile_clustercount = {};
  foreach my $i (1..8) {
    foreach my $y (1..8) {
      foreach my $add ( 0,20,40,60 ) {
        $test_lane_tile_clustercount->{$i}->{$y + $add} = undef;
      }
    }
  }

  is_deeply( $long_info->lane_tile_clustercount(), $test_lane_tile_clustercount, q{lane_tile_clustercount as expected} );

  $long_info=undef;
  lives_ok  { $long_info = test::long_info->new({id_run => 5636}); } q{created role_test (HiSeq run 5636, RunInfo.xml) object ok};
  cmp_ok($long_info->tile_count, '==', 48, 'correct tile count');
  lives_ok  { $long_info = test::long_info->new({id_run => 5636}); } q{created role_test (HiSeq run 5636, RunInfo.xml) object ok};
  cmp_ok($long_info->lane_count, '==', 8, 'correct lane count');
  lives_ok  { $long_info = test::long_info->new({id_run => 5636}); } q{created role_test (HiSeq run 5636, RunInfo.xml) object ok};
  cmp_ok($long_info->cycle_count, '==', 202, 'correct cycle count');
  lives_ok  { $long_info = test::long_info->new({id_run => 5636}); } q{created role_test (HiSeq run 5636, RunInfo.xml) object ok};
  cmp_ok($long_info->use_bases, 'eq', 'Y101,y101', 'correct use_bases string');
note($long_info->runfolder_path);

  my $tilelayout_columns;
  lives_ok  { 
    $long_info = test::long_info->new({id_run => 5636}); 
    $tilelayout_columns = $long_info->tilelayout_columns;
  } q{recreate object and call tilelayout_columns ok};
  cmp_ok($tilelayout_columns, '==', 6, 'correct tile columns');
  

}

{
  my $long_info;
  my $rfpath = q(t/data/long_info/nfs/sf20/ILorHSany_sf20/incoming/120110_M00119_0068_AMS0002022-00300);
  lives_ok { $long_info = test::long_info->new({runfolder_path=>$rfpath}); } q{create test role for dual index paired};
  cmp_ok( $long_info->expected_cycle_count, '==', 318, 'expected_cycle_count');
  lives_ok { $long_info = test::long_info->new({runfolder_path=>$rfpath}); } q{create test role for dual index paired};
  lives_and { cmp_deeply( [$long_info->read_cycle_counts], [151,8,8,151], 'read_cycle_counts match');} 'read_cycle_counts live and match';
  lives_ok { $long_info = test::long_info->new({runfolder_path=>$rfpath}); } q{create test role for dual index paired};
  lives_and { cmp_deeply( [$long_info->read1_cycle_range], [1,151], 'read1_cycle_range matches');} 'read1_cycle_range lives and matches';
  lives_ok { $long_info = test::long_info->new({runfolder_path=>$rfpath}); } q{create test role for dual index paired};
  lives_and { cmp_deeply( [$long_info->indexing_cycle_range], [152,167], 'indexing_cycle_range matches');} 'indexing_cycle_range lives and matches';
  lives_ok { $long_info = test::long_info->new({runfolder_path=>$rfpath}); } q{create test role for dual index paired};
  lives_and { cmp_ok( $long_info->index_length, '==', 16, 'index_length matches');} 'index_length lives and matches';
  lives_ok { $long_info = test::long_info->new({runfolder_path=>$rfpath}); } q{create test role for dual index paired};
  lives_and { cmp_deeply( [$long_info->read2_cycle_range], [168,318], 'read2_cycle_range matches');} 'read2_cycle_range lives and matches';
  lives_ok { $long_info = test::long_info->new({runfolder_path=>$rfpath}); } q{create test role for dual index paired};
  lives_and { ok( $long_info->is_indexed, 'is_indexed ok');} 'is_indexed lives and ok';
  lives_ok { $long_info = test::long_info->new({runfolder_path=>$rfpath}); } q{create test role for dual index paired};
  lives_and { ok( $long_info->is_paired_read, 'is_paired_read ok');} 'is_paired_read lives and ok';
}
1;
