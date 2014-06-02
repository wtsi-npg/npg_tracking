use strict;
use warnings;
use Carp;
use Test::More tests => 61;
use Test::Exception;
use File::Temp qw(tempdir);
use Cwd;
use File::Spec::Functions qw(catfile);

BEGIN {
  use_ok(q{npg_tracking::illumina::run::folder});
}

##################  start of test class ####################
package test::run::folder;
use Moose;
use File::Spec::Functions qw(splitdir);
use List::Util qw(first);

with qw{npg_tracking::illumina::run::short_info npg_tracking::illumina::run::folder};

has q{verbose} => ( isa => q{Bool}, is => q{ro} );

sub _build_run_folder {
  my ($self) = @_;
  my $path = $self->runfolder_path();
  return first {$_ ne q()} reverse splitdir($path);
}

no Moose;
##################  end of test class ####################

package main;

my $orig_dir = getcwd();
my $basedir = tempdir( CLEANUP => 1 );
$ENV{dev} = qw{non_existant_dev_enviroment}; #prevent pickup of user's config
$ENV{TEST_DIR} = $basedir; #so when npg_tracking::illumina::run::folder globs the test director

sub delete_staging {
  `rm -rf $basedir/nfs`;
  return 1;
}

sub create_staging {
  my ($qc_subpath, $basecalls_subpath, $config_path) = @_;
  delete_staging();
  `mkdir -p $qc_subpath`;
  `mkdir $basecalls_subpath`;
  `mkdir $config_path`;
  return 1;
}

sub _create_staging_no_recalibrated {
  my ($bustard_subpath, $basecalls_subpath, $config_path) = @_;
  delete_staging();
  `mkdir -p $bustard_subpath`;
  `mkdir $basecalls_subpath`;
  `mkdir $config_path`;
  return 1;
}
sub _create_staging_PB_cal {
  my ($bustard_subpath, $basecalls_subpath, $config_path) = @_;
  _create_staging_no_recalibrated($bustard_subpath, $basecalls_subpath, $config_path);
  `mkdir $bustard_subpath/PB_cal`;
  return 1;
}

{
  my $instr = 'HS2';
  my $id_run = q{1234};
  my $name = $instr . q{_1234};
  my $run_folder = q{123456_} . $instr . q{_1234} . q{_B_205NNABXX};
  my $runfolder_path = qq{$basedir/nfs/sf44/} . $instr . q{/analysis/} . $run_folder;
  my $data_subpath = $runfolder_path . q{/Data};
  my $reports_subpath = $data_subpath . q{/reports};
  my $intensities_subpath = $data_subpath . q{/Intensities};
  my $basecalls_subpath = $intensities_subpath . q{/BaseCalls};
  my $bustard_subpath = $intensities_subpath . q{/Bustard-2009-10-01};
  my $pb_cal_subpath = $bustard_subpath . q{/PB_cal};
  my $archive_subpath = $pb_cal_subpath . q{/archive};
  my $qc_subpath = $archive_subpath . q{/qc};
  my $config_path = $runfolder_path . q{/Config};

{
  use Moose::Meta::Class;
  my $path_info;

  lives_ok  { $path_info = Moose::Meta::Class->create_anon_class(
                roles => [qw/npg_tracking::illumina::run::folder/]
              )->new_object({id_run => $id_run}); } 
    q{no error creating object directly from a role without short reference};
  throws_ok { $path_info->runfolder_path(); }
    qr{Not enough information to obtain the path},
    q{Error getting runfolder_path as no 'short_reference' method in class};
}

{
  create_staging($qc_subpath, $basecalls_subpath, $config_path);
  my $path_info;
  lives_ok  { $path_info = test::run::folder->new({id_run => $id_run}); } q{created role_test object ok};
  is($path_info->runfolder_path(), $runfolder_path, q{runfolder_path found});
  is($path_info->run_folder(), $run_folder, q{run_folder worked out from runfolder_path});
  is($path_info->bustard_path(), $bustard_subpath, q{found a recalibrated directory, so able to work out bustard_path});
  is($path_info->analysis_path(), $bustard_subpath, q{found a recalibrated directory, so able to work out analysis_path});
  is($path_info->pb_cal_path(), $pb_cal_subpath, q{found a recalibrated directory, so able to work out bustard_path, and therefore pb_cal_path});
}

{
  my $path_info;
  lives_ok  { $path_info = test::run::folder->new({subpath => $archive_subpath}); } q{created role_test object ok};
  is($path_info->runfolder_path(), $runfolder_path, q{runfolder_path found});
  is($path_info->recalibrated_path(), $pb_cal_subpath,
    q{recalibrated_subpath found when subpath is/is below recalibrated directory});
}

{
  create_staging($qc_subpath, $basecalls_subpath, $config_path);
  `ln -s $pb_cal_subpath $runfolder_path/Latest_Summary`;

  my $path_info = test::run::folder->new({id_run => $id_run});
  
  is($path_info->runfolder_path(), $runfolder_path, q{runfolder_path found});
  is($path_info->basecall_path(), $basecalls_subpath, q{basecalls_subpath found when link present to recalibrated directory});
}

{
  create_staging($qc_subpath, $basecalls_subpath, $config_path);
  my $path_info = test::run::folder->new({id_run => $id_run});
  chdir qq{$pb_cal_subpath};
  is($path_info->runfolder_path(), $runfolder_path, q{runfolder_path found});
  my $returned_qc_path;
  lives_ok { $returned_qc_path = $path_info->qc_path(); } q{qc_subpath obtained ok};
  is($returned_qc_path, $qc_subpath, q{qc_subpath found when in recalibrated directory});
  is($path_info->reports_path(), $reports_subpath, q{reports path returned correctly});
}

{
  create_staging($qc_subpath, $basecalls_subpath, $config_path);
  my $path_info = test::run::folder->new({id_run => $id_run});

  throws_ok { $path_info->lane_archive_path() } qr/Validation failed for \'NpgTrackingLaneNumber\'/, 'error when position is not supplied';
  throws_ok { $path_info->lane_archive_path(q[toto]) } qr/Validation failed for \'NpgTrackingLaneNumber\'/, 'error when position is not an integer';
  throws_ok { $path_info->lane_archive_path(88) } qr/Validation failed for \'NpgTrackingLaneNumber\'/, 'error when position is a float';
  throws_ok { $path_info->lane_qc_path(10) } qr/Validation failed for \'NpgTrackingLaneNumber\'/, 'error when position is out of range';
  throws_ok { $path_info->lane_qc_path(0) } qr/Validation failed for \'NpgTrackingLaneNumber\'/, 'error when position is out of range';

  chdir qq{$pb_cal_subpath};
  $path_info->runfolder_path;
  my $archive_path = $path_info->archive_path();
  my $returned_qc_path = $path_info->qc_path();
  is($path_info->lane_archive_path(2), $archive_path . q[/lane2], 'lane 2 archive path');
  is($path_info->lane_archive_path(4), $archive_path . q[/lane4], 'lane 4 archive path');
  is($path_info->lane_qc_path(2), $archive_path . q[/lane2/qc], 'lane 2 qc path');
  is($path_info->lane_qc_path(4), $archive_path . q[/lane4/qc], 'lane 4 qc path');
}

{
  create_staging($qc_subpath, $basecalls_subpath, $config_path);
  my $path_info = test::run::folder->new({id_run => $id_run});
  ok(!@{$path_info->lane_archive_paths}, 'no lane archive paths are found');
  ok(!@{$path_info->lane_qc_paths}, 'no lane qc paths are found'); 
}

{
  my $lanes = [1,3,5,7];
  my $qlanes = [1,5,7];

  create_staging($qc_subpath, $basecalls_subpath, $config_path);
  foreach my $lane (@{$lanes}) {
    my $dir = qq[$archive_subpath/lane$lane];
    `mkdir $dir`;  
  }
  foreach my $lane (@{$qlanes}) {
    my $dir = qq[$archive_subpath/lane$lane] . q[/qc];
    `mkdir $dir`;  
  }

  my @expected_lanes = ();
  foreach my $lane (@{$lanes}) {
    push @expected_lanes, qq[$archive_subpath/lane$lane];
  }
  @expected_lanes = sort @expected_lanes;

  my @qexpected_lanes = ();
  foreach my $lane (@{$qlanes}) {
    push @qexpected_lanes, qq[$archive_subpath/lane$lane] . q[/qc];
  }
  @qexpected_lanes = sort @qexpected_lanes;
  
   my $path_info = test::run::folder->new({id_run => $id_run});
  is(join(q[ ], sort @{$path_info->lane_archive_paths}), join(q[ ], @expected_lanes), 'lane archive paths returned');
  is(join(q[ ], sort @{$path_info->lane_qc_paths}), join(q[ ], @qexpected_lanes), 'lane qc paths returned');
}

{
  _create_staging_PB_cal($bustard_subpath, $basecalls_subpath, $config_path);
  my $path_info = test::run::folder->new({ id_run => $id_run, run_folder => $run_folder, });
  is( $path_info->recalibrated_path(), qq{$bustard_subpath/PB_cal}, q{recalibrated_path points to PB_cal} );
  is( $path_info->analysis_path(), $bustard_subpath, q{analysis path inferred} );
  is( $path_info->pb_cal_path(), $path_info->recalibrated_path() , q{pb_cal_path and recalibrated_path are the same} );
  $path_info = test::run::folder->new({ id_run => $id_run, run_folder => $run_folder, });

  _create_staging_no_recalibrated($bustard_subpath, $basecalls_subpath, $config_path);
  throws_ok { $path_info->recalibrated_path(); } qr{found[ ]multiple[ ]possible[ ]bustard[ ]level[ ]directories}, q{more than one bustard level directory to potentially use as a recalibrated directory};
  `rm -rf $bustard_subpath`;
  is( $path_info->recalibrated_path(), $basecalls_subpath, q{BaseCalls dir used for recalibrated directory} );

  _create_staging_PB_cal($bustard_subpath, $basecalls_subpath, $config_path);
  `mkdir -p $bustard_subpath/PB_cal`;
  $path_info = test::run::folder->new({
    id_run => $id_run,
    run_folder => $run_folder,
    recalibrated_path => qq{$bustard_subpath/Help},
  });
  is( $path_info->analysis_path(), $bustard_subpath, q{analysis path inferred} );
  is( $path_info->bustard_path(), qq{$bustard_subpath},
    q{Help directory supplied as recalibrated_path, bustard worked out ok, so this is to be used} );
}
}

chdir $orig_dir; #need to leave directories before you can delete them....
eval { delete_staging(); } or do { carp 'unable to delete staging area'; };

my $hs_runfolder_dir = qq{$ENV{TEST_DIR}/nfs/sf44/ILorHSany_sf20/incoming/100914_HS3_05281_A_205MBABXX};

qx{mkdir -p $hs_runfolder_dir/Data/Intensities/BAM_basecalls_20101016-172254/no_cal/archive};
qx{mkdir -p $hs_runfolder_dir/Data/Intensities/Bustard1.8.1a2_01-10-2010_RTA.2/PB_cal/archive};
qx{mkdir -p $hs_runfolder_dir/Config};
qx{ln -s Data/Intensities/BAM_basecalls_20101016-172254/no_cal $hs_runfolder_dir/Latest_Summary};

{
  #note( $hs_runfolder_dir . q(/Data/Intensities/BAM_basecalls_20101016-172254/no_cal/archive));
  #note( -d $hs_runfolder_dir . q(/Data/Intensities/BAM_basecalls_20101016-172254/no_cal/archive));
  #note( qx{ls -lh $hs_runfolder_dir} );
  my $linked_dir = readlink ( $hs_runfolder_dir . q{/Latest_Summary} );
  #note $linked_dir;

  my $o = test::run::folder->new(
    runfolder_path => $hs_runfolder_dir,
  );
  my $recalibrated_path;
  lives_ok { $recalibrated_path = $o->recalibrated_path; } 'recalibrated_path from runfolder_path and summary link (no_cal)';
  cmp_ok( $recalibrated_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/BAM_basecalls_20101016-172254/no_cal), 'recalibrated_path from summary link (no_cal)' );
  cmp_ok( $o->bustard_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/BAM_basecalls_20101016-172254), 'bustard_path from summary link (no_cal)' );
  cmp_ok( $o->analysis_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/BAM_basecalls_20101016-172254), 'analysis_path from summary link (no_cal)' );
  cmp_ok( $o->basecall_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/BaseCalls), 'basecall_path from summary link (no_cal)' );
  cmp_ok( $o->runfolder_path, 'eq', $hs_runfolder_dir, 'runfolder_path from summary link (no_cal)' );
}

{
  my $o = test::run::folder->new(
    archive_path => $hs_runfolder_dir . q(/Data/Intensities/BAM_basecalls_20101016-172254/no_cal/archive),
  );
  cmp_ok( $o->analysis_path, 'eq',  $hs_runfolder_dir . q(/Data/Intensities/BAM_basecalls_20101016-172254),
    'analysis_path directly from archiva_path');
  cmp_ok( $o->recalibrated_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/BAM_basecalls_20101016-172254/no_cal), 'recalibrated_path from archive_path' );
  cmp_ok( $o->bustard_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/BAM_basecalls_20101016-172254), 'bustard_path from archive_path' );
  cmp_ok( $o->basecall_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/BaseCalls), 'basecall_path from archive_path' );
  cmp_ok( $o->runfolder_path, 'eq', $hs_runfolder_dir, 'runfolder_path from archive_path' );
}

{
  my $o = test::run::folder->new(
    archive_path => $hs_runfolder_dir . q(/Data/Intensities/Bustard1.8.1a2_01-10-2010_RTA.2/PB_cal/archive),
  );
  cmp_ok( $o->analysis_path, 'eq',  $hs_runfolder_dir . q(/Data/Intensities/Bustard1.8.1a2_01-10-2010_RTA.2),
    'analysis_path directly from archiva_path');
  cmp_ok($o->recalibrated_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/Bustard1.8.1a2_01-10-2010_RTA.2/PB_cal), 'recalibrated_path from archive_path' );
  cmp_ok($o->bustard_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/Bustard1.8.1a2_01-10-2010_RTA.2), 'bustard_path from archive_path' );
  cmp_ok($o->basecall_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/BaseCalls), 'basecall_path from archive_path' );
  cmp_ok($o->runfolder_path, 'eq', $hs_runfolder_dir, 'runfolder_path from archive_path' );
}

qx{rm $hs_runfolder_dir/Latest_Summary; ln -s Data/Intensities/Bustard1.8.1a2_01-10-2010_RTA.2/PB_cal $hs_runfolder_dir/Latest_Summary};
{
  #note( qx{ls -lh $hs_runfolder_dir} );
  my $linked_dir = readlink ( $hs_runfolder_dir . q{/Latest_Summary} );
  #note $linked_dir;

  my $o = test::run::folder->new(
    runfolder_path => $hs_runfolder_dir,
  );
  my $recalibrated_path;
  lives_ok { $recalibrated_path = $o->recalibrated_path; }
    'recalibrated_path from runfolder_path and  summary link';
  cmp_ok($recalibrated_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/Bustard1.8.1a2_01-10-2010_RTA.2/PB_cal),
    'recalibrated_path from summary link' );
  cmp_ok($o->bustard_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/Bustard1.8.1a2_01-10-2010_RTA.2),
    'bustard_path from  summary link' );
  cmp_ok($o->basecall_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/BaseCalls),
    'basecall_path from  summary link' );
  cmp_ok($o->runfolder_path, 'eq', $hs_runfolder_dir,
    'runfolder_path from  summary link' );
  cmp_ok($o->analysis_path, 'eq', $o->bustard_path, 'analysis_path from  summary link' );
}

{
  my $tdir = catfile(tempdir( CLEANUP => 1 ), q());
  my $testrundir = catfile($tdir, q(090414_IL24_2726));
  mkdir $testrundir;
  my $pi = test::run::folder->new({_folder_path_glob_pattern=>$tdir,id_run => 2});
  throws_ok {   $pi->runfolder_path } qr/No path/, 'throws when no run folders found for id_run';           
}

1;
