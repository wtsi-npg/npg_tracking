use strict;
use warnings;
use Test::More tests => 26;
use Test::Exception;
use Test::Warn;
use File::Copy;
use File::Temp qw(tempdir);
use File::Spec::Functions qw(catfile catdir);

use t::dbic_util;

use_ok('npg_tracking::illumina::runfolder');

my $schema = t::dbic_util->new->test_schema();
my $rf_name = q(240201_MS8_48385_A_MS3553611-300V2);
# We need a trailing slash after our directory for the globbing later.
my $testdir = catfile(tempdir( CLEANUP => 1 ), q());
my $testrundir = catdir($testdir,$rf_name);
mkdir $testrundir;

{
  my $rf = npg_tracking::illumina::runfolder->new(
    runfolder_path => $testrundir,
    npg_tracking_schema => undef
  );
  is ($rf->run_folder, $rf_name, 'run folder name is correct');
  throws_ok { $rf->id_run } qr/File not found/,
    'id_run cannot be computed, RunParameters.xml file is not found';

  $rf = npg_tracking::illumina::runfolder->new(
    _folder_path_glob_pattern => $testdir,
    id_run => 2,
    npg_tracking_schema => undef
  );
  throws_ok { $rf->run_folder } qr/Failed to infer runfolder_path/,
    'run folder name cannot be built';

  $rf = npg_tracking::illumina::runfolder->new(
    run_folder => $rf_name,
    _folder_path_glob_pattern => $testdir,
    npg_tracking_schema => undef
  );
  is ($rf->runfolder_path, $testrundir,
    'runfolder path by globbing for a run folder directory');

  my $id_run = 1;
  my $run_row = $schema->resultset('Run')->find($id_run);
  $run_row->update({folder_name => 'nomatch'});

  $rf = npg_tracking::illumina::runfolder->new(
    id_run => $id_run,
    run_folder => $rf_name,
    _folder_path_glob_pattern => $testdir,
    npg_tracking_schema => $schema
  );
  throws_ok { $rf->runfolder_path }
    qr/NPG tracking reports run 1 no longer on staging/,
    'error when the run does not have a staging tag';
  $run_row->set_tag(1, 'staging');
  my $path;
  warning_like { $path = $rf->runfolder_path }
    qr/Inconsistent db and given run folder name: nomatch, $rf_name/,
    'warning about mismatching run folder names';
  is ($path, $testrundir,
    'runfolder path via globbing for a run folder directory');

  $run_row->update({folder_name => $rf_name, folder_path_glob => $testdir});
 
  $rf = npg_tracking::illumina::runfolder->new(
    id_run => $id_run,
    run_folder => 'mismatch',
    npg_tracking_schema => $schema
  );
  warning_like { $path = $rf->runfolder_path }
    qr/Inconsistent db and given run folder name: $rf_name, mismatch/,
    'warning about mismatching run folder names';
  is ($path, $testrundir,
    'runfolder path via using the database record');
}

{
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

  my $rf = npg_tracking::illumina::runfolder->new(
    _folder_path_glob_pattern => $testdir,
    run_folder => $rf_name,
    npg_tracking_schema => undef
  );
  my $lane_count;
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

  my $rf = npg_tracking::illumina::runfolder->new(
    id_run              => 33333,
    npg_tracking_schema => undef);
  throws_ok { $rf->run_folder } qr/Failed to infer runfolder_path/,
   'error - not able to find a runfolder without db help';
  throws_ok { $rf->runfolder_path } qr/Failed to infer runfolder_path/,
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

    copy(join(q[/],$run_param_dir,$file_name), $run_params_file_path) or die 'Failed to copy file';

    my $li = new npg_tracking::illumina::runfolder(
      runfolder_path => $rf,
      npg_tracking_schema => $schema
    );
    is($li->id_run(), $expected_experiment_name, q[Expected id_run parsed from experiment name in run params]);
    unlink $run_params_file_path;
  }
};

subtest 'duplicate runfolders' => sub {
  plan tests => 9;

  my $staging = tempdir( CLEANUP => 1 );
  my $new_id_run = 898989;
  for (qw(incoming analysis outgoing)) {
    mkdir(catdir($staging, $_));
  }
  my $rf_name = '230920_NV11_47885';
  my $run_row = $schema->resultset('Run')->create({
    id_run               => $new_id_run,
    id_instrument        => 10,
    id_instrument_format => 10,
    team                 => 'A',
    folder_name          => $rf_name,
    folder_path_glob     => "$staging/*/"
  });
  $run_row->set_tag(1, 'staging');

  for (qw(analysis outgoing)) { 
    mkdir("$staging/$_/$rf_name");
  }

  my $rf_obj = npg_tracking::illumina::runfolder->new(
    id_run => $new_id_run, npg_tracking_schema => $schema);  
  throws_ok { $rf_obj->runfolder_path() }
    qr/Ambiguous paths for run folder found/,
    'error with a runfolder both in analysis and outgoing';

  $rf_obj = npg_tracking::illumina::runfolder->new(
    id_run => $new_id_run, npg_tracking_schema => $schema);  
  mkdir("$staging/incoming/$rf_name"); 
  throws_ok { $rf_obj->runfolder_path() }
    qr/Ambiguous paths for run folder found/,
    'error with a runfolder in incoming, analysis and outgoing';

  rmdir("$staging/outgoing/$rf_name");
  my $path;
  $rf_obj = npg_tracking::illumina::runfolder->new(
    id_run => $new_id_run, npg_tracking_schema => $schema);
  lives_ok { $path = $rf_obj->runfolder_path() }
    'no error with a runfolder in both incoming and analysis';
  is($path, "$staging/analysis/$rf_name",
    'correct runfolder path is retrieved');
  
  mkdir("$staging/outgoing/$rf_name");
  rmdir("$staging/analysis/$rf_name");
  $rf_obj = npg_tracking::illumina::runfolder->new(
    id_run => $new_id_run, npg_tracking_schema => $schema);
  lives_ok { $path = $rf_obj->runfolder_path() }
    'no error with a runfolder in both incoming and outgoing';
  is ($path, join(q[/], $staging, 'outgoing', $rf_name),
    'correct path is retrieved');

  $staging = catdir($staging, 'incoming');
  $run_row->update({folder_path_glob => "$staging/*/"});
  for (qw(incoming analysis outgoing)) {
    mkdir(catdir($staging, $_));
  }
  for (qw(incoming outgoing)) { 
    mkdir("$staging/$_/$rf_name");
  }

  $rf_obj = npg_tracking::illumina::runfolder->new(
    id_run => $new_id_run, npg_tracking_schema => $schema);  
  throws_ok { $rf_obj->runfolder_path() }
    qr/Ambiguous paths for run folder found/,
    'error with multiple runfolders with paths in incoming';

  rmdir("$staging/outgoing/$rf_name");
  $rf_obj = npg_tracking::illumina::runfolder->new(
    id_run => $new_id_run, npg_tracking_schema => $schema);
  lives_ok { $path = $rf_obj->runfolder_path() }
    'no error with a runfolder only in incoming';
  is ($path, join(q[/], $staging, 'incoming', $rf_name),
    'correct path is retrieved');
};

1;
