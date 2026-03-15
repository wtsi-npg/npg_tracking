use strict;
use warnings;
use Test::More tests => 5;
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
  plan tests => 51;

  my $single_index = npg_tracking::elembio::runfolder->new(
    runfolder_path => q[t/data/elembio_staging/AV244103/20250127_AV244103_1234_NT1850075L]
  );
  is($single_index->manufacturer, q[Element Biosciences],
    q[Elembio manufacturer is correct for single-index run]);
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

  _assert_read_structure(
    npg_tracking::elembio::runfolder->new(runfolder_path => $single_end_dir),
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
};

subtest 'npg_tracking::runfolder delegates to Elembio implementation' => sub {
  plan tests => 12;

  my $rf = npg_tracking::runfolder->new(
    runfolder_path => q[t/data/elembio_staging/AV244103/20250127_AV244103_1234_NT1850075L]
  );
  isa_ok($rf, 'npg_tracking::runfolder');
  is($rf->manufacturer, q[Element Biosciences],
    q[manufacturer is delegated to Elembio implementation]);
  is($rf->run_folder, q[20250127_AV244103_1234_NT1850075L],
    q[run folder name comes from path]);
  is($rf->lane_count, 2, q[lane count delegated to Elembio implementation]);
  is($rf->is_paired_read, 1, q[paired-read flag delegated to Elembio implementation]);
  is($rf->is_indexed, 1, q[indexed flag delegated to Elembio implementation]);
  is($rf->is_dual_index, 0, q[dual-index flag delegated to Elembio implementation]);
  is($rf->index_length, 8, q[index length delegated to Elembio implementation]);
  is($rf->expected_cycle_count, 310, q[expected cycle count delegated to Elembio implementation]);
  is_deeply([$rf->read_cycle_counts], [8, 151, 151],
    q[read cycle counts delegated to Elembio implementation]);

  my $runfolder_path = catdir(tempdir(CLEANUP => 1), 'elembio_subpath_runfolder');
  make_path(catdir($runfolder_path, 'BaseCalls'));
  _write_single_end_runparams($runfolder_path);
  my $lazy_rf = npg_tracking::runfolder->new(
    subpath => catdir($runfolder_path, 'BaseCalls')
  );
  is($lazy_rf->runfolder_path, $runfolder_path,
    q[runfolder_path is inferred from a subpath via RunParameters.json]);
  is_deeply([$lazy_rf->read_cycle_counts], [151],
    q[lazy-built runfolder_path still enables Elembio read parsing]);
};

subtest 'npg_tracking::runfolder preserves Illumina behaviour' => sub {
  plan tests => 4;

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
  is($rf->manufacturer, q[Illumina], q[Illumina manufacturer is unchanged]);
  is($rf->lane_count, 8, q[Illumina lane count is unchanged]);
  is($rf->index_length, 8, q[Illumina index length is unchanged]);
  is_deeply([$rf->read_cycle_counts], [76, 8, 76],
    q[Illumina read cycle counts are unchanged]);
};

1;
