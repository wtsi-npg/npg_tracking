use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Test::Warn;
use File::Temp qw(tempdir);
use File::Path qw(make_path remove_tree);
use Cwd;

BEGIN {
  # Test staging area prefix is defined in t/.npg/npg_tracking.
  # This config. file is used by this test.
  # prefix defined as /tmp/esa-sv-*
  local $ENV{'HOME'}=getcwd().'/t';
  use_ok(q{npg_tracking::illumina::run::folder});
}

##################  start of test class ####################
{
  package test::run::folder;
  use Moose;
  use File::Spec::Functions qw(splitdir);
  use List::Util qw(first);

  with qw{npg_tracking::illumina::run::folder};

  sub _build_run_folder {
    my ($self) = @_;
    my $path = $self->runfolder_path();
    return first {$_ ne q()} reverse splitdir($path);
  }

  no Moose;
}
##################  end of test class ####################

package main;

my $basedir = tempdir(
  template => 'esa-sv-XXXXXXXXXX', TMPDIR => 1, CLEANUP => 1);

subtest 'standard runfolder' => sub {
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
  $paths->{config_path} = $runfolder_path . q{/Config};

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

subtest 'runfolder with an unusual path' => sub {
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
