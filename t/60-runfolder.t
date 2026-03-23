use strict;
use warnings;
use Test::More tests => 5;
use File::Basename qw(basename);
use File::Path qw(make_path);
use File::Slurp qw(write_file);
use File::Spec::Functions qw(catdir catfile);
use File::Temp qw(tempdir);
use JSON;

use_ok('npg_tracking::elembio::runfolder');
use_ok('npg_tracking::runfolder');

sub _assert_read_structure {
  my ($rf, $label, $expected) = @_;

  is($rf->is_paired_read, $expected->{is_paired_read},
    "$label paired-read flag");
  is($rf->is_indexed, $expected->{is_indexed},
    "$label indexed flag");
  is($rf->is_dual_index, $expected->{is_dual_index},
    "$label dual-index flag");
  is($rf->index_length, $expected->{index_length},
    "$label index length");
  is_deeply([$rf->read_cycle_counts], $expected->{read_cycle_counts},
    "$label read cycle counts");
  is_deeply([$rf->reads_indexed], $expected->{reads_indexed},
    "$label indexed reads");
  is_deeply([$rf->read1_cycle_range], $expected->{read1_cycle_range},
    "$label read1 cycle range");
  is_deeply([$rf->read2_cycle_range], $expected->{read2_cycle_range},
    "$label read2 cycle range");
  is_deeply([$rf->index_read1_cycle_range], $expected->{index_read1_cycle_range},
    "$label index read1 cycle range");
  is_deeply([$rf->index_read2_cycle_range], $expected->{index_read2_cycle_range},
    "$label index read2 cycle range");
  is_deeply([$rf->indexing_cycle_range], $expected->{indexing_cycle_range},
    "$label combined indexing cycle range");
  is($rf->expected_cycle_count, $expected->{expected_cycle_count},
    "$label expected cycle count");
}

sub _assert_same_public_api {
  my ($generic, $concrete, $label) = @_;

  is($generic->run_folder, $concrete->run_folder, "$label run_folder");
  is($generic->manufacturer, $concrete->manufacturer, "$label manufacturer");
  is($generic->lane_count, $concrete->lane_count, "$label lane_count");
  is($generic->expected_cycle_count, $concrete->expected_cycle_count,
    "$label expected_cycle_count");
  is($generic->is_paired_read, $concrete->is_paired_read,
    "$label is_paired_read");
  is($generic->is_indexed, $concrete->is_indexed, "$label is_indexed");
  is($generic->is_dual_index, $concrete->is_dual_index,
    "$label is_dual_index");
  is($generic->index_length, $concrete->index_length, "$label index_length");
  is_deeply([$generic->read_cycle_counts], [$concrete->read_cycle_counts],
    "$label read_cycle_counts");
  is_deeply([$generic->reads_indexed], [$concrete->reads_indexed],
    "$label reads_indexed");
  is_deeply([$generic->indexing_cycle_range], [$concrete->indexing_cycle_range],
    "$label indexing_cycle_range");
  is_deeply([$generic->read1_cycle_range], [$concrete->read1_cycle_range],
    "$label read1_cycle_range");
  is_deeply([$generic->read2_cycle_range], [$concrete->read2_cycle_range],
    "$label read2_cycle_range");
  is_deeply([$generic->index_read1_cycle_range], [$concrete->index_read1_cycle_range],
    "$label index_read1_cycle_range");
  is_deeply([$generic->index_read2_cycle_range], [$concrete->index_read2_cycle_range],
    "$label index_read2_cycle_range");
}

sub _write_single_end_runparams {
  my ($runfolder_path) = @_;
  my $json = encode_json({
    RunName        => 'SINGLE_END',
    RunType        => 'Sequencing',
    Side           => 'SideA',
    Date           => '2025-03-15T12:00:00Z',
    InstrumentName => 'AV244103',
    RunFolderName  => '20250315_AV244103_SINGLE_END',
    Cycles         => {
      R1 => 151,
      R2 => 0,
      I1 => 0,
      I2 => 0,
    },
    ReadOrder      => 'R1',
    AnalysisLanes  => '1+2',
    Consumables    => {
      Flowcell => {
        SerialNumber => '2422551730',
      }
    },
  });
  write_file(catfile($runfolder_path, 'RunParameters.json'), $json);
}

subtest 'npg_tracking::elembio::runfolder read structure' => sub {
  plan tests => 57;

  my $single_index = npg_tracking::elembio::runfolder->new(
    runfolder_path => q[t/data/elembio_staging/AV244103/20250127_AV244103_1234_NT1850075L]
  );
  is($single_index->manufacturer, q[Element Biosciences],
    q[Elembio manufacturer is correct for single-index run]);
  ok(!$single_index->is_i5opposite, q[Elembio single-index run does not use opposite-orientation i5 handling]);

  _assert_read_structure(
    $single_index,
    q[single-index paired run],
    {
      is_paired_read          => 1,
      is_indexed              => 1,
      is_dual_index           => 0,
      index_length            => 8,
      read_cycle_counts       => [8, 151, 151],
      reads_indexed           => [1, 0, 0],
      read1_cycle_range       => [9, 159],
      read2_cycle_range       => [160, 310],
      index_read1_cycle_range => [1, 8],
      index_read2_cycle_range => [],
      indexing_cycle_range    => [1, 8],
      expected_cycle_count    => 310,
    }
  );

  my $dual_index = npg_tracking::elembio::runfolder->new(
    runfolder_path => q[t/data/elembio_staging/AV244103/20250101_AV244103_NT1234567E]
  );
  is($dual_index->manufacturer, q[Element Biosciences],
    q[Elembio manufacturer is correct for dual-index run]);
  is($dual_index->run_folder, q[20250101_AV244103_NT1234567E],
    q[Elembio run_folder follows the directory name even without JSON metadata]);
  ok($dual_index->is_i5opposite, q[Elembio dual-index run uses opposite-orientation i5 handling]);

  _assert_read_structure(
    $dual_index,
    q[dual-index paired run],
    {
      is_paired_read          => 1,
      is_indexed              => 1,
      is_dual_index           => 1,
      index_length            => 16,
      read_cycle_counts       => [8, 8, 151, 151],
      reads_indexed           => [1, 1, 0, 0],
      read1_cycle_range       => [17, 167],
      read2_cycle_range       => [168, 318],
      index_read1_cycle_range => [1, 8],
      index_read2_cycle_range => [9, 16],
      indexing_cycle_range    => [1, 16],
      expected_cycle_count    => 318,
    }
  );

  my $unindexed = npg_tracking::elembio::runfolder->new(
    runfolder_path => q[t/data/elembio_staging/AV244103/20250129_AV244103_B1234]
  );
  is($unindexed->manufacturer, q[Element Biosciences],
    q[Elembio manufacturer is correct for unindexed run]);
  ok(!$unindexed->is_i5opposite, q[Elembio unindexed run does not use opposite-orientation i5 handling]);

  _assert_read_structure(
    $unindexed,
    q[unindexed paired run],
    {
      is_paired_read          => 1,
      is_indexed              => 0,
      is_dual_index           => 0,
      index_length            => 0,
      read_cycle_counts       => [151, 151],
      reads_indexed           => [0, 0],
      read1_cycle_range       => [1, 151],
      read2_cycle_range       => [152, 302],
      index_read1_cycle_range => [],
      index_read2_cycle_range => [],
      indexing_cycle_range    => [],
      expected_cycle_count    => 302,
    }
  );

  my $single_end_dir = tempdir(CLEANUP => 1);
  _write_single_end_runparams($single_end_dir);

  my $single_end = npg_tracking::elembio::runfolder->new(runfolder_path => $single_end_dir);
  ok(!$single_end->is_i5opposite, q[Elembio single-end run does not use opposite-orientation i5 handling]);

  _assert_read_structure(
    $single_end,
    q[single-end run],
    {
      is_paired_read          => 0,
      is_indexed              => 0,
      is_dual_index           => 0,
      index_length            => 0,
      read_cycle_counts       => [151],
      reads_indexed           => [0],
      read1_cycle_range       => [1, 151],
      read2_cycle_range       => [],
      index_read1_cycle_range => [],
      index_read2_cycle_range => [],
      indexing_cycle_range    => [],
      expected_cycle_count    => 151,
    }
  );
  is(
    npg_tracking::elembio::runfolder->new(runfolder_path => $single_end_dir)
      ->run_folder,
    basename($single_end_dir),
    q[Elembio run_folder follows the local directory name]
  );
};

subtest 'npg_tracking::runfolder delegates to Elembio implementation' => sub {
  plan tests => 20;

  my $path = q[t/data/elembio_staging/AV244103/20250127_AV244103_1234_NT1850075L];
  my $rf = npg_tracking::runfolder->new(
    runfolder_path => $path
  );
  my $concrete = npg_tracking::elembio::runfolder->new(
    runfolder_path => $path
  );
  isa_ok($rf, 'npg_tracking::runfolder');
  _assert_same_public_api($rf, $concrete, q[generic and Elembio objects agree]);

  my $rf_missing_metadata = npg_tracking::runfolder->new(
    runfolder_path => q[t/data/elembio_staging/AV244103/20250101_AV244103_NT1234567E]
  );
  is($rf_missing_metadata->run_folder, q[20250101_AV244103_NT1234567E],
    q[generic run_folder is path-based when Elembio metadata is incomplete]);

  my $runfolder_path = catdir(tempdir(CLEANUP => 1), 'elembio_subpath_runfolder');
  make_path(catdir($runfolder_path, 'BaseCalls'));
  _write_single_end_runparams($runfolder_path);
  my $lazy_rf = npg_tracking::runfolder->new(
    subpath => catdir($runfolder_path, 'BaseCalls')
  );
  is($lazy_rf->runfolder_path, $runfolder_path,
    q[runfolder_path is inferred from a subpath via RunParameters.json]);
  is($lazy_rf->run_folder, q[elembio_subpath_runfolder],
    q[generic run_folder follows the inferred directory name]);
  is_deeply([$lazy_rf->read_cycle_counts], [151],
    q[lazy-built runfolder_path still enables Elembio read parsing]);
};

subtest 'npg_tracking::runfolder preserves Illumina behaviour' => sub {
  plan tests => 10;

  my $runfolder_path = catdir(tempdir(CLEANUP => 1), 'illumina_rf');
  make_path($runfolder_path);
  write_file(catfile($runfolder_path, 'RunInfo.xml'), <<'END_XML');
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
END_XML
  write_file(catfile($runfolder_path, 'runParameters.xml'), <<'END_XML');
<?xml version="1.0"?>
<RunParameters xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
</RunParameters>
END_XML

  my $rf = npg_tracking::runfolder->new(
    runfolder_path      => $runfolder_path,
    npg_tracking_schema => undef,
  );
  my $concrete = npg_tracking::illumina::runfolder->new(
    runfolder_path      => $runfolder_path,
    npg_tracking_schema => undef,
  );
  is($rf->manufacturer, q[Illumina], q[Illumina manufacturer is unchanged]);
  is($rf->lane_count, 8, q[Illumina lane count is unchanged]);
  is($rf->index_length, 8, q[Illumina index length is unchanged]);
  is_deeply([$rf->read_cycle_counts], [76, 8, 76],
    q[Illumina read cycle counts are unchanged]);
  is($rf->platform_HiSeq, $concrete->platform_HiSeq,
    q[generic platform_HiSeq matches Illumina implementation]);
  is($rf->platform_MiSeq, $concrete->platform_MiSeq,
    q[generic platform_MiSeq matches Illumina implementation]);
  is($rf->platform_NovaSeqX, $concrete->platform_NovaSeqX,
    q[generic platform_NovaSeqX matches Illumina implementation]);
  is($rf->surface_count, $concrete->surface_count,
    q[generic surface_count matches Illumina implementation]);

  my $override = npg_tracking::runfolder->new(
    runfolder_path        => $runfolder_path,
    npg_tracking_schema   => undef,
    is_indexed            => 0,
    expected_cycle_count  => 160,
  );
  is($override->is_indexed, 0, q[constructor can override is_indexed]);
  is($override->expected_cycle_count, 160,
    q[constructor can override expected_cycle_count]);
};

1;
