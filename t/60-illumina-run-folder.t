use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use Test::Warn;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use Cwd;
use Try::Tiny;

use t::dbic_util;

BEGIN {
  # Test staging area prefix is defined in t/.npg/npg_tracking.
  # This config. file is used by this test.
  # prefix defined as /tmp/esa-sv-*
  local $ENV{'HOME'}=getcwd().'/t';
  # Force reading 'npg_tracking config file.
  use_ok(q{npg_tracking::illumina::run::folder});
}

##################  start of test classes ##################
{
  package test::run::folder;
  use Moose;
  with qw{npg_tracking::illumina::run::folder};
}

{
  package test::nvx_short_info;
  use Moose;
  with 'npg_tracking::illumina::run::folder';

  has experiment_name => (is => 'rw');
}
##################  end of test classes ####################

package main;

my $basedir = tempdir(
  template => 'esa-sv-XXXXXXXXXX', TMPDIR => 1, CLEANUP => 1);

my $schema = t::dbic_util->new->test_schema(
  fixture_path => q[t/data/dbic_fixtures]);


subtest 'set and build id_run and run_folder attributes' => sub {
  plan tests => 8;

  throws_ok {
    test::run::folder->new(
      run_folder => q[export/sv03/my_folder],
      npg_tracking_schema => undef
    )
  } qr{Attribute \(run_folder\) does not pass the type constraint},
    'error supplying a directory path as the run_folder attribute value';

  throws_ok {
    test::run::folder->new(run_folder => q[], npg_tracking_schema => undef)
  } qr{Attribute \(run_folder\) does not pass the type constraint},
    'error supplying an empty atring as the run_folder attribute value';

  my $obj = test::run::folder->new(
    run_folder => q[my_folder],
    id_run => 1234,
    npg_tracking_schema => undef
  );
  is ($obj->run_folder, 'my_folder', 'the run_folder value is as set');
  is ($obj->id_run, 1234, 'id_run value is as set');

  $obj = test::run::folder->new(
    run_folder => q[my_folder],
    npg_tracking_schema => undef
  );
  throws_ok { $obj->id_run } qr{Unable to identify id_run with data provided},
    'error building id_run';

  $obj  = test::run::folder->new(
    run_folder => 'xxxxxx',
    npg_tracking_schema => $schema
  );
  throws_ok { $obj->id_run } qr{Unable to identify id_run with data provided},
    'error building id_run when no db record for the run folder exists';

  my $rf = q[20231017_LH00210_0012_B22FCNFLT3];

  {
    # DB schema handle is not set, an attempt to build it will be made.
    # Since the user HOME is reset, the file with db credentials does not exist. 
    local $ENV{'HOME'}=getcwd().'/t';
    $obj = test::run::folder->new(run_folder => $rf);
    throws_ok { $obj->id_run } qr{Unable to identify id_run with data provided},
      'error building id_run';
  }

  $obj = test::run::folder->new(
    run_folder => $rf,
    npg_tracking_schema => $schema
  );
  is ($obj->id_run, 47995, 'id_run value retrieved from the database record');
};

subtest 'test id_run extraction from within experiment_name' => sub {
  plan tests => 8;

  my $short_info;
  {
    # DB schema handle is not set, an attempt to build it will be made.
    # Since the user HOME is reset, the file with db credentials does not exist. 
    local $ENV{'HOME'}=getcwd().'/t';
 
    $short_info = test::nvx_short_info->new(
      experiment_name => '45678_NVX1_A',
      run_folder => 'not_a_folder'
    );
    my $id_run;
    warning_like { $id_run = $short_info->id_run }
      qr /Unable to connect to NPG tracking DB for faster globs/,
      'warning about a failure to connect to the database';
    is($id_run, '45678', 'id_run parsed from experiment name');
  }

  $short_info = test::nvx_short_info->new(
    experiment_name => '  45678_NVX1_A   ',
    run_folder => 'not_a_folder',
    npg_tracking_schema => undef
  );
  is($short_info->id_run, '45678',
    'id_run parsed from loosely formatted experiment name');

  $short_info = test::nvx_short_info->new(
    experiment_name => '45678_NVX1_A   ',
    run_folder => 'not_a_folder',
    npg_tracking_schema => undef
  );
  is($short_info->id_run, '45678',
    'id_run parsed from experiment name with postfix spaces');

  $short_info = test::nvx_short_info->new(
    experiment_name => '  45678_NVX1_A',
    run_folder => 'not_a_folder',
    npg_tracking_schema => undef
  );
  is($short_info->id_run, '45678',
    'id_run parsed from experiment name with prefixed spaces');

  $short_info = test::nvx_short_info->new(
    experiment_name => '45678',
    run_folder => 'not_a_folder',
    npg_tracking_schema => undef
  );
  is($short_info->id_run, '45678', 'Bare id_run as experiment name is fine');

  $short_info = test::nvx_short_info->new(
    experiment_name => 'NovaSeqX_WHGS_TruSeqPF_NA12878',
    run_folder => 'not_a_folder',
    npg_tracking_schema => undef
  );
  throws_ok { $short_info->id_run }
    qr{Unable to identify id_run with data provided},
    'Custom run name cannot be parsed';

  $short_info = test::nvx_short_info->new(
    id_run => '45678',
    experiment_name => '56789_NVX1_A',
    run_folder => 'not_a_folder',
    npg_tracking_schema => undef
  );
  is($short_info->id_run, '45678', 'Set id_run wins over experiment_name');
};

subtest 'standard runfolder, no DB access' => sub {
  plan tests => 20;

  my $run_folder = q{20231019_LH00275_0006_B19NJCA4LE};
  my $runfolder_path = join q{/}, $basedir, q{IL_seq_data},
     q{analysis}, $run_folder;

  my $paths = {};
  $paths->{runfolder_path} = $runfolder_path;
  $paths->{data_subpath} = $runfolder_path . q{/Data};
  $paths->{intensities_subpath} = $paths->{data_subpath} . q{/Intensities};
  $paths->{basecalls_subpath} = $paths->{intensities_subpath} . q{/BaseCalls};
  $paths->{bbcalls_subpath} = $paths->{intensities_subpath} .
    q{/BAM_basecalls_20240223-125418};
  $paths->{pb_cal_subpath} = $paths->{bbcalls_subpath} . q{/no_cal};
  $paths->{archive_subpath} = $paths->{pb_cal_subpath} . q{/archive};
  $paths->{no_archive_subpath} = $paths->{bbcalls_subpath} . q{/no_archive};
  $paths->{pp_archive_subpath} = $paths->{bbcalls_subpath} . q{/pp_archive};
  $paths->{qc_subpath} = $paths->{archive_subpath} . q{/qc};

  for my $path (values %{$paths}) {
    make_path($path);
  }

  my $path_info;
  lives_ok  {
    $path_info = test::run::folder->new(
      run_folder => $run_folder,
      npg_tracking_schema => undef
    )
  } q{created role_test object ok};
  is($path_info->runfolder_path, $runfolder_path, q{runfolder_path found});
  my $p;
  warning_like { $p = $path_info->recalibrated_path() }
    qr/Latest_Summary does not exist or is not a link/,
    'warning about Latest_Summary absence';
  is($p, $paths->{pb_cal_subpath}, 'recalibrated path');
  is($path_info->analysis_path(), $paths->{bbcalls_subpath},
    q{found a recalibrated directory, so able to work out analysis_path});
  is($path_info->archive_path(), $paths->{archive_subpath}, q{archive path});
  is($path_info->no_archive_path(), $paths->{no_archive_subpath},
    q{no_archive path});
  is($path_info->pp_archive_path(), $paths->{pp_archive_subpath},
    q{pp_archive path});
  is($path_info->qc_path(), $paths->{qc_subpath}, q{qc path});
  is($path_info->basecall_path(), $paths->{basecalls_subpath}, q{basecall path});
  is($path_info->dragen_analysis_path(), $runfolder_path . q{/Analysis},
    q{DRAGEN analysis path});

  $path_info = test::run::folder->new(
    subpath => $paths->{archive_subpath},
    npg_tracking_schema => undef
  );
  is($path_info->runfolder_path(), $runfolder_path, q{runfolder_path found});
  warning_like { $p = $path_info->recalibrated_path() }
    qr/Latest_Summary does not exist or is not a link/,
    'warning about Latest_Summary absence';
  is($p, $paths->{pb_cal_subpath}, q{recalibrated_path found});
  is($path_info->analysis_path(), $paths->{bbcalls_subpath}, 'analysis path');

  my $ls = qq{$runfolder_path/Latest_Summary};
  symlink $paths->{pb_cal_subpath}, $ls;
  my $other = $paths->{intensities_subpath} . q{/BAM_basecalls_2019-10-01};
  make_path $other;
  $path_info = test::run::folder->new(
    run_folder => $run_folder,
    npg_tracking_schema => undef
  );
  is($path_info->runfolder_path, $runfolder_path, q{runfolder_path found});
  is($path_info->basecall_path(), $paths->{basecalls_subpath},
    q{basecalls_path found when Latest_Summary link is present});

  unlink $ls;

  $path_info = test::run::folder->new(
    run_folder => $run_folder,
    npg_tracking_schema => undef
  );
  is($path_info->runfolder_path, $runfolder_path, q{runfolder_path found});
  throws_ok { $path_info->recalibrated_path() }
    qr/Multiple bam_basecall directories in the intensity directory/,
    'multiple bam_basecall directories cannot be resolved ' .
    'without the Latest_Summary link';
  
  remove_tree $other;
  remove_tree $paths->{bbcalls_subpath};
  throws_ok { $path_info->recalibrated_path() }
    qr/bam_basecall directory not found in the intensity directory/,
    'absence of bam_basecall directory is an error';
};

subtest 'runfolder with an unusual path, no DB access' => sub {
  plan tests => 12;

  my $path = join q[/], $basedir, qw/aa bb cc dd/;
  make_path $path;
  my $rf = test::run::folder->new(
    archive_path => $path,
    npg_tracking_schema => undef
  );
  my @methods = map {$_ .'_path'} qw/runfolder intensity basecall recalibrated/;
  for my $path_method (@methods) {
    throws_ok { $rf->$path_method }
      qr/Nothing looks like a run folder in any subpath/,
      "cannot infer $path_method"; 
  }
  is ($rf->bam_basecall_path, undef, 'bam_basecall_path not set');
  is ($rf->analysis_path, join(q[/], $basedir, qw/aa bb/), 'analysis path');

  $rf = test::run::folder->new(
    runfolder_path => $basedir,
    archive_path   => $path,
    npg_tracking_schema => undef
  );
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

  my $rf = test::run::folder->new(
    runfolder_path => $path,
    npg_tracking_schema => undef
  );
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

  $rf = test::run::folder->new(
    runfolder_path => $path,
    npg_tracking_schema => undef
  );
  like ($rf->set_bam_basecall_path(), qr/BAM_basecalls_\d+/, 
    'setting bam_basecall_path without a custom suffix');

  $rf = test::run::folder->new(
    runfolder_path => $path,
    npg_tracking_schema => undef
  );
  is ($rf->set_bam_basecall_path('t/data', 1), 't/data',
    'bam_basecall_path is set to the path given');
};

1;
