use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;
use Test::Warn;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use File::Spec::Functions qw(catfile);
use Test::MockObject::Extends;
use Moose::Meta::Class;
use Cwd;

BEGIN {
  local $ENV{'HOME'}=getcwd().'/t';
  use_ok(q{npg_tracking::illumina::run::folder});
}

##################  start of test class ####################
{
  package test::run::folder;
  use Moose;
  use File::Spec::Functions qw(splitdir);
  use List::Util qw(first);

  with qw{npg_tracking::illumina::run::short_info
          npg_tracking::illumina::run::folder};

  sub _build_run_folder {
    my ($self) = @_;
    my $path = $self->runfolder_path();
    return first {$_ ne q()} reverse splitdir($path);
  }

  no Moose;
}
##################  end of test class ####################

package main;

my $basedir = tempdir( CLEANUP => 1 );
local $ENV{dev} = qw{non_existant_dev_enviroment}; #prevent pickup of user's config
local $ENV{TEST_DIR} = $basedir; #so when npg_tracking::illumina::run::folder globs the test director

subtest 'standard runfolder' => sub {
  plan tests => 28;

  my $instr = 'HS2';
  my $id_run = q{1234};
  my $name = $instr . q{_1234};
  my $run_folder = q{123456_} . $instr . q{_1234} . q{_B_205NNABXX};
  my $runfolder_path = qq{$basedir/nfs/sf44/} . $instr .
                       q{/analysis/} . $run_folder;
  my $data_subpath = $runfolder_path . q{/Data};
  my $intensities_subpath = $data_subpath . q{/Intensities};
  my $basecalls_subpath = $intensities_subpath . q{/BaseCalls};
  my $bbcalls_subpath = $intensities_subpath . q{/BAM_basecalls_2009-10-01};
  my $pb_cal_subpath = $bbcalls_subpath . q{/no_cal};
  my $archive_subpath = $pb_cal_subpath . q{/archive};
  my $no_archive_subpath = $bbcalls_subpath . q{/no_archive};
  my $pp_archive_subpath = $bbcalls_subpath . q{/pp_archive};
  my $qc_subpath = $archive_subpath . q{/qc};
  my $config_path = $runfolder_path . q{/Config};

  my $delete_staging = sub {
    remove_tree qq{$basedir/nfs};
  };
  my $create_staging = sub {
    $delete_staging->();
    make_path $qc_subpath;
    make_path $config_path;
  };

  my $path_info;

  lives_ok  { $path_info = Moose::Meta::Class->create_anon_class(
                roles => [qw/npg_tracking::illumina::run::folder/]
              )->new_object({id_run => $id_run}); } 
    q{no error creating object directly from a role without short reference};
  throws_ok { $path_info->runfolder_path(); }
    qr{Not enough information to obtain the path},
    q{Error getting runfolder_path as no 'short_reference' method in class};

  $create_staging->();

  lives_ok  { $path_info = test::run::folder->new(id_run => $id_run) }
    q{created role_test object ok};
  my $p;
  warning_like { $p = $path_info->runfolder_path() }
    qr/Unable to connect to NPG tracking DB for faster globs/,
    'expected warnings';
  is($p, $runfolder_path, q{runfolder_path found});
  is($path_info->run_folder(), $run_folder,
    q{run_folder worked out from runfolder_path});
  warning_like { $p = $path_info->recalibrated_path() }
    qr/Latest_Summary does not exist or is not a link/,
    'warning about lt absence';
  is($p, $pb_cal_subpath, 'recalibrated path');
  is($path_info->analysis_path(), $bbcalls_subpath,
    q{found a recalibrated directory, so able to work out analysis_path});
  is($path_info->archive_path(), $archive_subpath, q{archive path});
  is($path_info->no_archive_path(), $no_archive_subpath, q{no_archive path});
  is($path_info->pp_archive_path(), $pp_archive_subpath, q{pp_archive path});
  is($path_info->qc_path(), $qc_subpath, q{qc path});
  is($path_info->basecall_path(), $basecalls_subpath, q{basecall path});
  is($path_info->dragen_analysis_path(), "$runfolder_path/Analysis",
    q{DRAGEN analysis path});

  lives_ok  { $path_info = test::run::folder->new(subpath => $archive_subpath) }
    q{created role_test object ok};
  is($path_info->runfolder_path(), $runfolder_path, q{runfolder_path found});
  warning_like { $p = $path_info->recalibrated_path() }
    qr/Latest_Summary does not exist or is not a link/,
    'warning about lt absence';
  is($p, $pb_cal_subpath, q{recalibrated_path found});
  is($path_info->analysis_path(), $bbcalls_subpath, 'analysis path');

  $create_staging->();
  my $ls = qq{$runfolder_path/Latest_Summary};
  symlink $pb_cal_subpath, $ls;
  my $other = qq{$intensities_subpath/BAM_basecalls_2019-10-01};
  make_path $other;

  $path_info = test::run::folder->new(id_run => $id_run);
  warning_like { $p = $path_info->runfolder_path() }
    qr/Unable to connect to NPG tracking DB for faster globs/,
    'expected warnings';
  is($p, $runfolder_path, q{runfolder_path found});
  is($path_info->basecall_path(), $basecalls_subpath,
    q{basecalls_subpath found when link present to recalibrated directory});

  unlink $ls;

  $path_info = test::run::folder->new(id_run => $id_run);
  warning_like { $p = $path_info->runfolder_path() }
    qr/Unable to connect to NPG tracking DB for faster globs/,
    'expected warnings';
  is($p, $runfolder_path, q{runfolder_path found});
  throws_ok { $path_info->recalibrated_path() }
    qr/Multiple bam_basecall directories in the intensity directory/,
    'multiple bam_basecall directories cannot be resolved ' .
    'without the Latest_Summary link';
  
  remove_tree $other;
  remove_tree $bbcalls_subpath;
  throws_ok { $path_info->recalibrated_path() }
    qr/bam_basecall directory not found in the intensity directory/,
    'absence of bam_basecall directory is an error';

  $create_staging->();
  $path_info = test::run::folder->new(
    id_run            => $id_run,
    run_folder        => $run_folder,
    recalibrated_path => qq{$bbcalls_subpath/Help},
  );
  is( $path_info->analysis_path(), $bbcalls_subpath, q{analysis path inferred} );

  $delete_staging->();
};

subtest 'runfolder with unusual structure' => sub {
  plan tests => 12;

  my $path = join q[/], $basedir, qw/aa bb cc dd/;
  make_path $path;
  my $rf = test::run::folder->new(archive_path => $path);
  throws_ok { $rf->runfolder_path }
    qr/Nothing looks like a run_folder in any given subpath/,
    'cannot infer intensity_path';
  throws_ok { $rf->intensity_path }
    qr/Nothing looks like a run_folder in any given subpath/,
    'cannot infer intensity_path';
  throws_ok { $rf->basecall_path }
    qr/Nothing looks like a run_folder in any given subpath/,
    'cannot infer basecall_path';
  throws_ok { $rf->recalibrated_path }
    qr/Nothing looks like a run_folder in any given subpath/,
    'cannot infer recalibrated_path';
  is ($rf->bam_basecall_path, undef, 'bam_basecall_path not set');
  is ($rf->analysis_path, join(q[/], $basedir, qw/aa bb/), 'analysis path');

  $rf = test::run::folder->new( runfolder_path => $basedir,
                                archive_path   => $path );
  is ($rf->intensity_path, "$basedir/Data/Intensities",
    'intensity_path returned though it does not exist');
  is ($rf->basecall_path, "$basedir/Data/Intensities/BaseCalls",
    'basecall_path returned though it does not exist');
  is ($rf->bam_basecall_path, undef, 'bam_basecall_path not set');
  is ($rf->analysis_path, join(q[/], $basedir, qw/aa bb/), 'analysis path');
  my $rpath;
  warnings_like { $rpath = $rf->recalibrated_path } [
      qr/Summary link $basedir\/Latest_Summary does not exist or is not a link/,
      qr/derived from archive_path does not end with no_cal/
    ], 'warning about the name of the recalibrated dir';
  is ($rpath,  join(q[/], $basedir, qw/aa bb cc/), 'recalibrated path');
};

subtest 'setting bam_basecall_path' => sub {
  plan tests => 10;

  my $path = join q[/], $basedir, qw/ee/;
  make_path $path;

  my $rf = test::run::folder->new(runfolder_path => $path);
  is ($rf->bam_basecall_path, undef, 'bam_basecall_path is not set');
  ok (!$rf->has_bam_basecall_path(), 'bam_basecall_path is not set');
  is ($rf->analysis_path, q{}, 'analysis path is empty');
  my $expected = join q[/], $basedir, 'ee',
                 'Data', 'Intensities', 'BAM_basecalls_today';
  is ($rf->set_bam_basecall_path('today'), $expected,  'set bam_basecall_path');
  is ($rf->bam_basecall_path(), $expected,  'bam_basecall_path is set');
  ok ($rf->has_bam_basecall_path(), 'bam_basecall_path is set');
  is ($rf->analysis_path, q{}, 'analysis path is empty');
  throws_ok { $rf->set_bam_basecall_path('today') }
    qr/bam_basecall is already set to $expected/,
    'bam_basecall_path can be set only once';

  $rf = test::run::folder->new(runfolder_path => $path);
  like ($rf->set_bam_basecall_path(), qr/BAM_basecalls_\d+/, 
    'setting bam_basecall_path without a custom suffix');

  $rf = test::run::folder->new(runfolder_path => $path);
  is ($rf->set_bam_basecall_path('t/data', 1), 't/data',
    'bam_basecall_path is set to the path given');
};

subtest 'standard run folder No 2' => sub {
  plan tests => 10;

  my $hs_runfolder_dir = qq{$basedir/nfs/sf44/ILorHSany_sf20/incoming/100914_HS3_05281_A_205MBABXX};
  make_path qq{$hs_runfolder_dir/Data/Intensities/BAM_basecalls_20101016-172254/no_cal/archive};
  make_path qq{$hs_runfolder_dir/Config};
  symlink q{Data/Intensities/BAM_basecalls_20101016-172254/no_cal},
    qq{$hs_runfolder_dir/Latest_Summary};

  my $linked_dir = readlink ( $hs_runfolder_dir . q{/Latest_Summary} );

  my $o = test::run::folder->new(
    runfolder_path => $hs_runfolder_dir,
  );
  my $recalibrated_path;
  lives_ok { $recalibrated_path = $o->recalibrated_path; } 'recalibrated_path from runfolder_path and summary link';
  cmp_ok( $recalibrated_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/BAM_basecalls_20101016-172254/no_cal), 'recalibrated_path from summary link' );
  cmp_ok( $o->analysis_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/BAM_basecalls_20101016-172254), 'analysis_path from summary link' );
  cmp_ok( $o->basecall_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/BaseCalls), 'basecall_path from summary link' );
  cmp_ok( $o->runfolder_path, 'eq', $hs_runfolder_dir, 'runfolder_path from summary link (no_cal)' );

  $o = test::run::folder->new(
    archive_path => $hs_runfolder_dir .
      q(/Data/Intensities/BAM_basecalls_20101016-172254/no_cal/archive)
  );
  cmp_ok( $o->analysis_path, 'eq',  $hs_runfolder_dir . q(/Data/Intensities/BAM_basecalls_20101016-172254),
    'analysis_path directly from archiva_path');
  cmp_ok( $o->recalibrated_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/BAM_basecalls_20101016-172254/no_cal), 'recalibrated_path from archive_path' );
  cmp_ok( $o->basecall_path, 'eq', $hs_runfolder_dir . q(/Data/Intensities/BaseCalls), 'basecall_path from archive_path' );
  cmp_ok( $o->runfolder_path, 'eq', $hs_runfolder_dir, 'runfolder_path from archive_path' );

  unlink qq{$hs_runfolder_dir/Latest_Summary};
  # link points to non-existing directory
  symlink q{Data/Intensities/Bustard1.8.1a2_01-10-2010_RTA.2/PB_cal},
    qq{$hs_runfolder_dir/Latest_Summary};

  $o = test::run::folder->new(
    runfolder_path => $hs_runfolder_dir,
  );
  throws_ok { $o->recalibrated_path; }
    qr/is not a directory, cannot be the recalibrated path/,
    'link points to non-existing directory - error';
};

{
  my $tdir = catfile(tempdir( CLEANUP => 1 ), q());
  my $testrundir = catfile($tdir, q(090414_IL24_2726));
  mkdir $testrundir;
  my $pi = test::run::folder->new({_folder_path_glob_pattern=>$tdir, id_run => 2});
  throws_ok {   $pi->runfolder_path } qr/No paths to run folder found/,
    'error when no run folders found for id_run';           
}

local $ENV{TEST_DIR} = q(t/data/long_info);
my $incoming = join q[/], $ENV{TEST_DIR}, q[nfs/sf20/ILorHSany_sf20/incoming];

subtest 'tests for short_reference method' => sub {
  plan tests => 10;

  my $test;
  lives_ok { $test = Moose::Meta::Class->create_anon_class(
      roles => [qw(npg_tracking::illumina::run::folder)],
    )->new_object(npg_tracking_schema => undef);
  } 'anon class with no short_reference method';
  throws_ok { $test->runfolder_path } qr/Not enough information/,
   'no short_reference method - error';

  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder)],
  );
  $testc->add_attribute(q[short_reference] => (
    q[is] => q[ro], q[default] => undef ));

  lives_ok {
    $test = $testc->new_object(npg_tracking_schema => undef)
  } 'anon class with short_reference undef';
  throws_ok { $test->runfolder_path } qr/Not enough information/,
    'short_reference undef - error';

  # short_reference method, with no suitable folder
  $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder)],
  );
  $testc->add_attribute(q[short_reference] => (
    q[is] => q[ro], q[default] => undef ));
  lives_ok {
    $test = $testc->new_object( npg_tracking_schema => undef,
                                short_reference => q[does_not_exist]);
  } 'anon class with short_reference for non existant folder';
  throws_ok { $test->runfolder_path } qr/No paths to run folder found/,
    'no run folder found';

  # short_reference method, with suitable folder
  $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder)],
  );
  $testc->add_attribute(q[short_reference] => (
    q[is] => q[ro], q[default] => undef ));
  lives_ok {
    $test = $testc->new_object( npg_tracking_schema => undef,
                                short_reference => q[5636]);
  } 'anon class with short_reference for folder';
  lives_and { is $test->runfolder_path,
    qq($incoming/101217_HS11_05636_A_90061ACXX) } 'run folder found';

  # short_reference method, with suitable folder
  $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder)],
  );
  $testc->add_attribute(q[short_reference] =>
    ( q[is] => q[ro], q[default] => undef ));
  lives_ok {
    $test = $testc->new_object(npg_tracking_schema => undef,
                               short_reference => q[100914_HS3_05281_A_205MBABXX]);
  } 'anon class with short_reference for folder';
  lives_and { is $test->runfolder_path,
    qq($incoming/100914_HS3_05281_A_205MBABXX) } 'run folder found';
};

my $testschema = Test::MockObject::Extends->new( q(npg_tracking::Schema) );
$testschema->mock(q(resultset), sub{return shift;});
#diag $testschema->resultset;
my $testrun = Test::MockObject::Extends->new(q(npg_tracking::Schema::Result::Run));
$testschema->mock(q(find), sub{
  my($self,$id_run) = @_;
  return $id_run ? $testrun : undef;
});
$testrun->mock(q(is_tag_set), sub{ return 0; });

subtest 'schema, no id_run, but with short ref and a folder' => sub {
  plan tests => 2;

  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder)],
  );
  $testc->add_attribute(q[short_reference] => ( q[is] => q[ro], q[default] => undef ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[short_reference] => q[100914_HS3_05281_A_205MBABXX], q[npg_tracking_schema] => $testschema );
  } 'anon class, schema, no id_run, with short_reference for folder';
  lives_and { is $test->runfolder_path, qq($incoming/100914_HS3_05281_A_205MBABXX) } ' run folder found';
};

subtest 'schema, id_run, no staging tag' => sub {
  plan tests => 2;

  $testrun->mock(q(is_tag_set), sub{ return 0; });
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder)],
  );
  $testc->add_attribute(q[short_reference] => ( q[is] => q[ro], q[default] => undef ));
  $testc->add_attribute(q[id_run] => ( q[is] => q[ro], q[default] => 0 ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[id_run] => 5281, q[short_reference] => q[100914_HS3_05281_A_205MBABXX], q[npg_tracking_schema] => $testschema );
  } 'anon class, schema, id_run, with short_reference for folder - but no staging tag';
  throws_ok { $test->runfolder_path } qr/NPG tracking reports run \d* no longer on staging/, ' no run folder found';
};

subtest 'schema, id_run, staging tag, no glob, no folder_name' => sub {
  plan tests => 2;

  $testrun->mock(q(is_tag_set), sub{ return 1; });
  $testrun->mock(q(folder_path_glob), sub{ return; });
  $testrun->mock(q(folder_name), sub{ return; });
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder)],
  );

  $testc->add_attribute(q[short_reference] => ( q[is] => q[ro], q[default] => undef ));
  $testc->add_attribute(q[id_run] => ( q[is] => q[ro], q[default] => 0 ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[id_run] => 5281, q[short_reference] => q[100914_HS3_05281_A_205MBABXX], q[npg_tracking_schema] => $testschema );
  } 'anon class, schema, id_run, with short_reference for folder - staging tag but no folder name or glob from DB';
  lives_and { is $test->runfolder_path, qq($incoming/100914_HS3_05281_A_205MBABXX) } ' run folder found';
};

subtest 'schema, no short ref, id_run, staging tag, glob, folder_name' => sub {
  plan tests => 3;

  $testrun->mock(q(folder_path_glob), sub{ return q[t/data/long_info/{export,nfs}/sf20/ILorHSany_sf20/*]; });
  $testrun->mock(q(folder_name), sub{ return q[100914_HS3_05281_A_205MBABXX]; });
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder)],
  );
  $testc->add_attribute(q[id_run] => ( q[is] => q[ro], q[default] => 0 ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[id_run] => 5281, q[short_reference] => q[100914_HS3_05281_A_205MBABXX], q[npg_tracking_schema] => $testschema );
  } 'anon class, schema, id_run, no short_reference, staging tag and folder name and glob';
  lives_and { is $test->runfolder_path, qq($incoming/100914_HS3_05281_A_205MBABXX) } ' run folder found';

  $testrun->mock(q(folder_path_glob), sub{ return q[t/data/long_info/{export,nfs}/sf20/ILorHSany_sf20/*/]; });
  $test = $testc->new_object( q[id_run] => 5281, q[short_reference] => q[100914_HS3_05281_A_205MBABXX], q[npg_tracking_schema] => $testschema );
  lives_and { is $test->runfolder_path, qq($incoming/100914_HS3_05281_A_205MBABXX) } ' run folder found and does not contain a double slash';
};

1;
