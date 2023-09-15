use strict;
use warnings;
use Test::More tests => 28;
use Test::Exception;
use Archive::Tar;
use IO::File;
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile rel2abs catdir);
use Cwd;

use t::dbic_util;

use_ok('npg_tracking::illumina::runfolder');

my $schema = t::dbic_util->new->test_schema();

my $testrundata = catfile(rel2abs(dirname(__FILE__)),q(data),q(090414_IL24_2726.tar.bz2));

my $origdir = getcwd;
my $testdir = catfile(tempdir( CLEANUP => 1 ), q()); #we need a trailing slash after our directory for the globbing later
chdir $testdir or die "Cannot change to temporary directory $testdir";
diag ("Extracting $testrundata to $testdir");
system('tar','xjf',$testrundata) == 0 or Archive::Tar->extract_archive($testrundata, 1);
chdir $origdir; #so cleanup of testdir can go ahead
my $testrundir = catdir($testdir,q(090414_IL24_2726));

{
  my $rf;

  lives_ok {
    $rf = npg_tracking::illumina::runfolder->new( runfolder_path => $testrundir);
  } 'runfolder from valid runfolder_path';
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
  {  my $name;
    lives_ok {
      $rf = npg_tracking::illumina::runfolder->new(_folder_path_glob_pattern=>$testdir, id_run=> 2726, npg_tracking_schema => undef);
      $name = $rf->name;
    } 'runfolder from valid id_run';
    is($name, q(IL24_2726), 'name parsed');
  }
  my $rfpath =  catdir($testdir,q(090414_IL99_2726));
  mkdir $rfpath;
  throws_ok {
    $rf = npg_tracking::illumina::runfolder->new(_folder_path_glob_pattern=>$testdir, id_run=> 2726, npg_tracking_schema => undef);
    $rf->runfolder_path;
  } qr/Ambiguous paths/, 'throws when ambiguous run folders found for id_run';
  rmdir catdir($testdir,q(090414_IL99_2726));
  symlink $testrundir, catdir($testdir,q(superfoo_r2726));
  lives_ok {
    $rf = npg_tracking::illumina::runfolder->new(_folder_path_glob_pattern=>$testdir, id_run=> 2726, npg_tracking_schema => undef);
    $rf->runfolder_path;
  } 'lives when ambiguous run folders found for id_run but they correspond, via links or such, to the same folder';
  unlink catdir($testdir,q(superfoo_r2726));
  throws_ok {
    $rf = npg_tracking::illumina::runfolder->new(_folder_path_glob_pattern=>$testdir, id_run=> 2, npg_tracking_schema => undef);
    $rf->run_folder;
  } qr/No path/, 'throws when no run folders found for id_run';
  my $path;
  my $expected_cycle_count;
  my (@read_cycle_counts, @indexing_cycle_range, @read1_cycle_range, @read2_cycle_range);


  my $fh;
  my $runinfofile = qq[$testrundir/RunInfo.xml];
  open($fh, '>', $runinfofile) or die "Could not open file '$runinfofile' $!";
  print $fh <<"ENDXML";
<?xml version="1.0"?>
<RunInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Version="3">
<Run>
  <Reads>
  <Read Number="1" NumCycles="76" IsIndexedRead="N" />
  <Read Number="2" NumCycles="8" IsIndexedRead="Y" />
  <Read Number="3" NumCycles="76" IsIndexedRead="N" />
  </Reads>
  <FlowcellLayout LaneCount="8" SurfaceCount="2" SwathCount="1" TileCount="60">
  </FlowcellLayout>
</Run>
</RunInfo>
ENDXML
  close $fh;
  my $runparametersfile = qq[$testrundir/runParameters.xml];
  open($fh, '>', $runparametersfile) or die "Could not open file '$runparametersfile' $!";
  print $fh <<"ENDXML";
<?xml version="1.0"?>
  <RunParameters xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
 </RunParameters>
ENDXML
 close $fh;

  my $lane_count;
  $rf = npg_tracking::illumina::runfolder->new(_folder_path_glob_pattern=>$testdir, name=> q(090414_IL24_2726), npg_tracking_schema => undef);
  lives_ok {
    $lane_count = $rf->lane_count;
  } 'finds and parses recipe file';
  is($lane_count,8,'lane_count');
  my $tile_count;
  lives_ok {
    $tile_count = $rf->tile_count;
  } 'loads tilelayout file';
  is($tile_count,120,'tile_count');
}

{
  my $test_runfolder_path;
  lives_ok {
    $test_runfolder_path = npg_tracking::illumina::runfolder->new(
      runfolder_path=> $testrundir, npg_tracking_schema => undef);
  } 'runfolder from valid runfolder_path';
  is($test_runfolder_path->run_folder(), '090414_IL24_2726',
    q{run folder obtained ok when runfolder_path used in construction});
}

{
  my $new_name = q(4567XXTT98);
  my $testrundir_new = catdir($testdir, $new_name);
  rename $testrundir, $testrundir_new;
  my $id_run = 33333;
  my $data = {
    actual_cycle_count   => 30,
    batch_id             => 939,
    expected_cycle_count => 37,
    id_instrument        => 3,
    id_run               => $id_run,
    id_run_pair          => 0,
    team                 => 'RAD',
    is_paired            => 0,
    priority             => 1,
    flowcell_id          => 'someid',
    id_instrument_format => 1,
    folder_name          => $new_name,
    folder_path_glob     => $testdir
  };

  my $run_row = $schema->resultset('Run')->create($data);
  $run_row->set_tag(1, 'staging');

  my $rf;

  $rf = npg_tracking::illumina::runfolder->new(
    id_run              => 33333,
    npg_tracking_schema => undef);
  throws_ok { $rf->run_folder } qr/No paths to run folder found/,
   'error - not able to find a runfolder without db help';
  throws_ok { $rf->runfolder_path } qr/No paths to run folder found/,
   'error - not able to find a runfolder without db help';

  $rf = npg_tracking::illumina::runfolder->new(
      id_run              => 33333,
      npg_tracking_schema => $schema);
  is ($rf->run_folder, $new_name, 'runfolder name with db helper');
  is ($rf->runfolder_path,  $testrundir_new, 'runfolder path with db helper');

  $rf = npg_tracking::illumina::runfolder->new(
    run_folder          => $new_name,
    npg_tracking_schema => undef);
  throws_ok { $rf->id_run } qr/No paths to run folder found/,
    'error - not able to infer run id without db help';
  throws_ok { $rf->runfolder_path } qr/No paths to run folder found/,
    'error - not able to find a runfolder without db help';

  $rf = npg_tracking::illumina::runfolder->new(
      run_folder          => $new_name,
      npg_tracking_schema => $schema);
  is ($rf->id_run, 33333, 'id_run with db helper');
  is ($rf->runfolder_path,  $testrundir_new, 'runfolder path with db helper');

  $rf = npg_tracking::illumina::runfolder->new(
      runfolder_path      => $testrundir_new,
      npg_tracking_schema => $schema);
  is ($rf->id_run, 33333, 'id_run with db helper');
  is ($rf->run_folder, $new_name, 'runfolder with db helper');

  rename $testrundir_new, $testrundir;
}

subtest 'getting id_run from experiment name in run parameters' => sub {
  plan tests => 8;

  my $basedir = tempdir( CLEANUP => 1 );
  my $rf = join q[/], $basedir, 'runfolder_id_run';
  mkdir $rf;

  my %data = (
    'runParameters.hiseq4000.xml'       => { 'rpf' => 'runParameters', 'expname' => '24359' },
    'runParameters.hiseq.rr.single.xml' => { 'rpf' => 'runParameters', 'expname' => '25835' },
    'runParameters.hiseq.rr.truseq.xml' => { 'rpf' => 'runParameters', 'expname' => '21604' },
    'runParameters.hiseq.rr.twoind.xml' => { 'rpf' => 'runParameters', 'expname' => '25689' },
    'runParameters.hiseq.rr.xml'        => { 'rpf' => 'runParameters', 'expname' => '24409' },
    'runParameters.hiseq.xml'           => { 'rpf' => 'runParameters', 'expname' => '24235' },
    'runParameters.hiseqx.upgraded.xml' => { 'rpf' => 'runParameters', 'expname' => '24420' },
    'runParameters.hiseqx.xml'          => { 'rpf' => 'runParameters', 'expname' => '24422' },
  );

  my $expname_data = \%data;
  my $run_param_dir = 't/data/run_params';

  for my $file_name (sort keys % $expname_data) {
    note $file_name;
    my $expected_experiment_name = $expname_data->{$file_name}->{'expname'};
    my $param_prefix = $expname_data->{$file_name}->{'rpf'};
    my $run_params_file_path = qq[$rf/$param_prefix.xml];

    use File::Copy;
    copy(join(q[/],$run_param_dir,$file_name), $run_params_file_path) or die 'Failed to copy file';

    my $li = new npg_tracking::illumina::runfolder(
      runfolder_path => $rf,
      npg_tracking_schema => $schema
    );

    is($li->id_run(), $expected_experiment_name, q[Expected id_run parsed from experiment name in run params]);
    `rm $run_params_file_path`
  }
};

1;
