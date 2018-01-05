use strict;
use warnings;
use Test::More tests => 36;
use Test::Exception;
use Carp;
use Archive::Tar;
use IO::File;
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile rel2abs catdir);
use Cwd;

use_ok('npg_tracking::illumina::runfolder');

my $CLEANUP=1;

my $testrundata = catfile(rel2abs(dirname(__FILE__)),q(data),q(090414_IL24_2726.tar.bz2));

my $origdir = getcwd;
my $testdir = catfile(tempdir( CLEANUP => $CLEANUP ), q()); #we need a trailing slash after our directory for the globbing later
chdir $testdir or croak "Cannot change to temporary directory $testdir";
diag ("Extracting $testrundata to $testdir");
system('tar','xjf',$testrundata) == 0 or Archive::Tar->extract_archive($testrundata, 1);
chdir $origdir; #so cleanup of testdir can go ahead
my $testrundir = catdir($testdir,q(090414_IL24_2726));

{
  my $rf;
  throws_ok {
    npg_tracking::illumina::runfolder->new( subpath=> catdir(qw(foo bar)))->runfolder_path;
  } qr/nothing looks like a run_folder in any given subpath/, 'none existant subpath';
  { my $derivedpath;
    lives_ok {
      $rf = npg_tracking::illumina::runfolder->new( subpath=> catdir($testrundir,q(Images)));
      $derivedpath = $rf->runfolder_path();
    } 'runfolder from valid subpath';
    is($derivedpath,$testrundir, 'path from subpath');
  }
  { my $is_rta;
    lives_ok { $is_rta = $rf->is_rta; } 'check is_rta';
    ok(!$is_rta, 'not RTA run');
  }
  lives_ok {
    $rf = npg_tracking::illumina::runfolder->new( path=> $testrundir);
  } 'runfolder from valid path';
  { my $id_run;
    lives_ok { $id_run = $rf->id_run; } 'id_run parsed';
    is($id_run, 2726, 'id_run correct');
  }
  { my $name;
    lives_ok { $name = $rf->name; } 'name parsed';
    is($name, q(IL24_2726), 'name correct');
  }
  mkdir catdir($testrundir,qw(Data));
  mkdir catdir($testrundir,qw(Data Intensities));
  { my $is_rta;
    lives_ok { $is_rta = $rf->is_rta; } 'check is_rta';
    ok($is_rta, 'RTA run - when Intensities directory added');
  }
  {  my $name;
    lives_ok {
      $rf = npg_tracking::illumina::runfolder->new(_folder_path_glob_pattern=>$testdir, id_run=> 2726, npg_tracking_schema => undef);
      $name = $rf->name;
    } 'runfolder from valid id_run';
    is($name, q(IL24_2726), 'name parsed');
  }
  mkdir catdir($testdir,q(090414_IL99_2726));
  throws_ok {
    $rf = npg_tracking::illumina::runfolder->new(_folder_path_glob_pattern=>$testdir, id_run=> 2726, npg_tracking_schema => undef);
    $rf->path;
  } qr/Ambiguous paths/, 'throws when ambiguous run folders found for id_run';
  rmdir catdir($testdir,q(090414_IL99_2726));
  symlink $testrundir, catdir($testdir,q(superfoo_r2726));
  lives_ok {
    $rf = npg_tracking::illumina::runfolder->new(_folder_path_glob_pattern=>$testdir, id_run=> 2726, npg_tracking_schema => undef);
    $rf->path;
  } 'lives when ambiguous run folders found for id_run but they correspond, via links or such, to the same folder';
  unlink catdir($testdir,q(superfoo_r2726));
  throws_ok {
    $rf = npg_tracking::illumina::runfolder->new(_folder_path_glob_pattern=>$testdir, id_run=> 2, npg_tracking_schema => undef);
    $rf->path;
  } qr/No path/, 'throws when no run folders found for id_run';
  my $path;
  lives_ok {
    $rf = npg_tracking::illumina::runfolder->new(_folder_path_glob_pattern=>$testdir, name=> q(IL24_2726), npg_tracking_schema => undef);
    $path = $rf->path;
  } 'runfolder from valid name';
  is($path, $testrundir, 'path found');
  IO::File->new(catfile($testrundir,q(Recipe_foo.xml)), q(w));
  throws_ok {
    $rf->expected_cycle_count;
  } qr/Multiple recipe files found:/, 'throws when multiple recipes found';
  unlink catfile($testrundir,q(Recipe_foo.xml));
  my $expected_cycle_count;
  my (@read_cycle_counts, @indexing_cycle_range, @read1_cycle_range, @read2_cycle_range);
  lives_ok {
    $expected_cycle_count = $rf->expected_cycle_count;
    @read_cycle_counts = $rf->read_cycle_counts;
    @indexing_cycle_range = $rf->indexing_cycle_range;
    @read1_cycle_range = $rf->read1_cycle_range;
    @read2_cycle_range = $rf->read2_cycle_range;
  } 'finds and parses recipe file';
  is($expected_cycle_count,61,'expected_cycle_count');
  is_deeply(\@read_cycle_counts,[54,7],'read_cycle_counts');
  is_deeply(\@read1_cycle_range,[1,54],'read1_cycle_range');
  is_deeply(\@indexing_cycle_range,[55,61],'indexing_cycle_range');
  is_deeply(\@read2_cycle_range,[],'read2_cycle_range');
  my $lane_count;
  lives_ok {
    $rf = npg_tracking::illumina::runfolder->new(_folder_path_glob_pattern=>$testdir, name=> q(090414_IL24_2726), npg_tracking_schema => undef);
    $lane_count = $rf->lane_count;
  } 'finds and parses recipe file';
  is($lane_count,8,'lane_count');
  rename catfile($testrundir,q(Config),q(TileLayout.xml)), catfile($testrundir,q(Config),q(gibber_TileLayout.xml));
  throws_ok {
    $rf->tile_count;
  } qr/Can't open/, 'throws on no TileLayout.xml';
  rename catfile($testrundir,q(Config),q(gibber_TileLayout.xml)), catfile($testrundir,q(Config),q(TileLayout.xml));
  my $tile_count;
  lives_ok {
    $tile_count = $rf->tile_count;
  } 'loads tilelayout file';
  is($tile_count,100,'tile_count');
}

{
  my $test_runfolder_path;
  lives_ok {
    $test_runfolder_path = npg_tracking::illumina::runfolder->new(
      runfolder_path=> $testrundir, npg_tracking_schema => undef);
  } 'runfolder from valid runfolder_path';
  is($test_runfolder_path->path(), $testrundir,
    q{path obtained ok when runfolder_path used in construction});

  lives_ok {
    $test_runfolder_path = npg_tracking::illumina::runfolder->new(
      path=> $testrundir, npg_tracking_schema => undef);
  } 'runfolder from valid path';
  is($test_runfolder_path->runfolder_path(), $testrundir,
    q{runfolder_path obtained ok when path used in construction});
}

1;
