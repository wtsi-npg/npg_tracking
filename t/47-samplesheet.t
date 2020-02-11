use strict;
use warnings;
use Test::More tests => 11;
use Test::LongString;
use Test::Exception;
use File::Slurp;
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;

use t::dbic_util;
local $ENV{'dev'} = q(wibble); # ensure we're not going live anywhere
local $ENV{'HOME'} = q(t/);

use_ok('npg::samplesheet');
use_ok('st::api::lims');

my $schema = t::dbic_util->new->test_schema();
local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q(t/data/samplesheet);

my $dir = tempdir( CLEANUP => 1 );

subtest 'object creation' => sub {
   plan tests => 7;

  my $result = q();
  dies_ok { npg::samplesheet->new( repository=>$dir, output=>\$result)->process }
    'sample sheet process fails when neither run object nor id_run given';

  my $ss;
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>7007); } 'sample sheet object - no output provided';
  cmp_ok($ss->output, 'eq', '/nfs/sf49/ILorHSorMS_sf49/samplesheets/wibble/MS0001309-300.csv', 'default output location (with zeroes trimmed appropriately)');

  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946); } 'sample sheet object - no output provided';
  cmp_ok($ss->output, 'eq', '/nfs/sf49/ILorHSorMS_sf49/samplesheets/wibble/000000000-A0616.csv', 'default output location');

  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>7007); } 'sample sheet object - no output provided';
  my $orig_flowcell_id = $ss->run->flowcell_id;
  $ss->run->flowcell_id(q(MS2000132-500V2));
  cmp_ok($ss->output, 'eq', '/nfs/sf49/ILorHSorMS_sf49/samplesheets/wibble/MS2000132-500V2.csv', 'default output location copes with V2 MiSeq cartirdges/reagent kits');
};

subtest 'values conversion' => sub {
  plan tests => 12;

  is (npg::samplesheet::_csv_compatible_value(undef), q[], 'value conversion: undef to empty string');
  is (npg::samplesheet::_csv_compatible_value(q[]), q[], 'value conversion: empty string - no conversion');
  is (npg::samplesheet::_csv_compatible_value(0), 0, 'value conversion: zero - no conversion');
  is (npg::samplesheet::_csv_compatible_value(33), 33, 'value conversion: integer - no conversion');
  is (npg::samplesheet::_csv_compatible_value(33.9), 33.9, 'value conversion: float - no conversion');
  is (npg::samplesheet::_csv_compatible_value('simple_string'), 'simple_string',
    'value conversion: simple string - no conversion');
  is (npg::samplesheet::_csv_compatible_value('simple,str,ing'), 'simple%2Cstr%2Cing',
    'value conversion: commas replaced by URI escapes');
  is (npg::samplesheet::_csv_compatible_value("simple,str\ning"), 'simple%2Cstr%0Aing',
    'value conversion: comma and LF by URI escapes');
  is (npg::samplesheet::_csv_compatible_value("s  imple\nstr\r\ning\r\n"), 's  imple%0Astr%0D%0Aing%0D%0A',
    'value conversion: LFs, CRs and multiple white spaces replaced by URI escapes');
  is (npg::samplesheet::_csv_compatible_value(['d@sea', 'r@see']), 'd@sea r@see', 'value conversion: array concatenated');
  is (npg::samplesheet::_csv_compatible_value({'middle' => 250, 'from' => 200, 'to' => 300,}),
    'from:200 middle:250 to:300', 'value conversion: hash stringified');
  my $v = npg::samplesheet->new(repository=>q(t/data/repos1), npg_tracking_schema=>$schema, id_run=>7007);
  throws_ok {npg::samplesheet::_csv_compatible_value($v)} qr/Do not know how to serialize/, 'error converting an object';
};

subtest 'simple default samplesheet' => sub {
  plan tests => 6;

my $expected_result_7007 = << 'RESULT_7007';
[Header],,,
Investigator Name,mq1,,
Project Name,Strongyloides ratti transcriptomics,,
Experiment Name,7007,,
Date,2011-11-03T12:16:00,,
Workflow,GenerateFastQ,,
Chemistry,Default,,
,,,
[Reads],,,
150,,,
150,,,
,,,
[Settings],,,
,,,
[Manifests],,,
,,,
[Data],,,
Sample_ID,Sample_Name,GenomeFolder,
3789277,Strongyloides ratti,,
RESULT_7007
  $expected_result_7007 =~ s/\n/\r\n/smg;

  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>7007, output=>\$result); } 'sample sheet object for unplexed paired run';
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, $expected_result_7007);

  my $run = $schema->resultset(q(Run))->find(7007);
  $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, run=>$run, output=>\$result); } 'sample sheet object from run object - no id_run given';
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, $expected_result_7007);
};

subtest 'default samplesheet for a plexed paired run' => sub {
  plan tests => 3;

  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946, output=>\$result); } 'samplesheet object for plexed paired run';
  my $expected_result = << 'RESULT_6946';
[Header],,,,
Investigator Name,mq1,,,
Project Name,Kapa HiFi test,,,
Experiment Name,6946,,,
Date,2011-10-14T16:32:00,,,
Workflow,GenerateFastQ,,,
Chemistry,Default,,,
,,,,
[Reads],,,,
151,,,,
151,,,,
,,,,
[Settings],,,,
,,,,
[Manifests],,,,
,,,,
[Data],,,,
Sample_ID,Sample_Name,GenomeFolder,Index,
3789278,Salmonella pullorum,,ATCACGTT,
3789279,Bordetella Pertussis,,CGATGTTT,
3789280,Plasmodium Falciparum,,TTAGGCAT,
3789281,Homo sapiens,,TGACCACT,
3789282,Salmonella pullorum,,ACAGTGGT,
3789283,Bordetella Pertussis,,GCCAATGT,
3789284,Plasmodium Falciparum,,CAGATCTG,
3789285,Homo sapiens,,ACTTGATG,
3789286,Salmonella pullorum,,GATCAGCG,
3789287,Bordetella Pertussis,,TAGCTTGT,
3789288,Plasmodium Falciparum,,GGCTACAG,
3789289,Homo sapiens,,CTTGTACT,
RESULT_6946
  $expected_result =~ s/\n/\r\n/smg;
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, $expected_result);
};

subtest 'default samplesheet for a plexed paired run with reference fallback' => sub {
  plan tests => 3;

  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>7825, output=>\$result); } 'sample sheet object for plexed paired run';
  my $expected_result = << 'RESULT_7825';
[Header],,,,
Investigator Name,nh4,,,
Project Name,Mate Pair R%26D,,,
Experiment Name,7825,,,
Date,2012-04-03T16:39:48,,,
Workflow,GenerateFastQ,,,
Chemistry,Default,,,
,,,,
[Reads],,,,
75,,,,
75,,,,
,,,,
[Settings],,,,
,,,,
[Manifests],,,,
,,,,
[Data],,,,
Sample_ID,Sample_Name,GenomeFolder,Index,
4894529,Mouse_test_3kb,,ATCACGTTAT,
4894528,Tetse_3kb,,CGATGTTTAT,
4894527,PfIT_454_5kb,,ACTTGATGAT,
4894525,PfIT_Sanger_5kb,,GATCAGCGAT,
4894526,PfIT_SOLiD5500_5kb,,TAGCTTGTAT,
RESULT_7825
  $expected_result =~ s/\n/\r\n/smg;
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, $expected_result, 'PhiX used as fall back reference');
};

subtest 'default samplesheet, mkfastq option enabled' => sub {
   plan tests => 3;

  # with the mkfastq option we get an extra leading column, Lane
  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>7826, mkfastq => 1, output=>\$result); }
    'sample sheet object mkfastq';
  my $expected_result = << 'RESULT_mkfastq';
[Header],,,,,
Investigator Name,nh4,,,,
Project Name,Mate Pair R%26D,,,,
Experiment Name,7826,,,,
Date,2012-04-03T16:39:48,,,,
Workflow,GenerateFastQ,,,,
Chemistry,Amplicon,,,,
,,,,,
[Reads],,,,,
75,,,,,
8,,,,,
,,,,,
[Settings],,,,,
,,,,,
[Manifests],,,,,
,,,,,
[Data],,,,,
Lane,Sample_ID,Sample_Name,GenomeFolder,Index,Index2,
1,7826_1_ATCACGTTATAAAAAA,7826_1_ATCACGTTATAAAAAA,,ATCACGTT,ATAAAAAA,
1,7826_1_CGATGTTTATTTTTTT,7826_1_CGATGTTTATTTTTTT,,CGATGTTT,ATTTTTTT,
1,7826_1_ACTTGATGATCCCCCC,7826_1_ACTTGATGATCCCCCC,,ACTTGATG,ATCCCCCC,
1,7826_1_GATCAGCGATGGGGGG,7826_1_GATCAGCGATGGGGGG,,GATCAGCG,ATGGGGGG,
1,7826_1_TAGCTTGTATACACGT,7826_1_TAGCTTGTATACACGT,,TAGCTTGT,ATACACGT,
RESULT_mkfastq
  $expected_result =~ s/\n/\r\n/smg;
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, $expected_result, 'mkfastq created');
};

subtest 'default samplesheet for dual index' => sub {
   plan tests => 3;

  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>7826, output=>\$result); } 'sample sheet object for dual index';
  my $expected_result = << 'RESULT_7826';
[Header],,,,
Investigator Name,nh4,,,
Project Name,Mate Pair R%26D,,,
Experiment Name,7826,,,
Date,2012-04-03T16:39:48,,,
Workflow,GenerateFastQ,,,
Chemistry,Amplicon,,,
,,,,
[Reads],,,,
75,,,,
8,,,,
,,,,
[Settings],,,,
,,,,
[Manifests],,,,
,,,,
[Data],,,,
Sample_ID,Sample_Name,GenomeFolder,Index,Index2,
4894529,Mouse_test_3kb,,ATCACGTT,ATAAAAAA,
4894528,Tetse_3kb,,CGATGTTT,ATTTTTTT,
4894527,PfIT_454_5kb,,ACTTGATG,ATCCCCCC,
4894525,PfIT_Sanger_5kb,,GATCAGCG,ATGGGGGG,
4894526,PfIT_SOLiD5500_5kb,,TAGCTTGT,ATACACGT,
RESULT_7826
  $expected_result =~ s/\n/\r\n/smg;
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, $expected_result, 'Dual indexes created');
};

subtest 'extended samplesheets' => sub {
  plan tests => 23;

  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, extend => 1, id_run=>7007, output=>\$result); } 'extended sample sheet object for unplexed paired run';
  ok(!$ss->_dual_index, 'no dual index');
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, read_file('t/data/samplesheet/7007_extended.csv'));

  $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946, extend => 1, output=>\$result); } 'extended sample sheet object for plexed paired run';
  ok(!$ss->_dual_index, 'no dual index');
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, read_file('t/data/samplesheet/6946_extended.csv'));

  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/test45];
  # assign batch_id for run 3905 - one control lane and 7 libraries
  $schema->resultset('Run')->find(6946)->update({batch_id => 4775});

  $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946, extend => 1, output=>\$result); }
    'extended sample sheet object for unplexed paired 8 lane run with a control lane';
  lives_ok { $ss->process(); } 'sample sheet generated';
  is_string($result, read_file('t/data/samplesheet/1control7libs_extended.csv'));

  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/test45];
  # assign batch_id for run 7690 - 8 pools
  $schema->resultset('Run')->find(6946)->update({batch_id => 16249});

  $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946, extend => 1, output=>\$result); }
    'extended sample sheet object for plexed paired 8 lane run';
  ok(!$ss->_dual_index, 'no dual index');
  lives_ok { $ss->process(); } 'sample sheet generated';
  is_string($result, read_file('t/data/samplesheet/8pools_extended.csv'));

  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/samplesheet];
  # assign batch_id for run 11114 - 4 pools 4 libs
  $schema->resultset('Run')->find(6946)->update({batch_id => 23798});

  $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946, extend => 1, output=>\$result); }
    'extended sample sheet object for plexed paired run with both pool and library lanes';
  ok($ss->_dual_index, 'dual index from a 16 char first index');
  lives_ok { $ss->process(); } 'sample sheet generated';
  is_string($result, read_file('t/data/samplesheet/4pool4libs_extended.csv'));

  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/samplesheet];
  $schema->resultset('Run')->find(6946)->update({batch_id => 1,});

  $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946, extend => 1, output=>\$result); }
    'extended sample sheet object for plexed paired run with both pool and library lanes';
  ok($ss->_dual_index, 'dual index from two indexes in LIMs');
  lives_ok { $ss->process(); } 'sample sheet generated';
  is_string($result, read_file('t/data/samplesheet/dual_index_extended.csv'));
};

subtest 'samplesheets for data for multiple runs' => sub {
  plan tests => 7;

  my $path = 't/data/samplesheet/novaseq_multirun.csv';
  my $rpt_list = '26480:1:9;26480:2:9;26480:3:9;26480:4:9;' .
                 '28780:1:4;28780:2:4;28780:3:4;28780:4:4';
  my @lims = st::api::lims->new(driver_type => 'samplesheet',
                                path        => $path, 
                                rpt_list    => $rpt_list)->children;

  throws_ok { npg::samplesheet->new(
    id_run => 26480, lims => \@lims, extend => 1)->process() 
  } qr/Run data set \(id_run or run\) where LIMs data are for multiple runs/,
    'error if id_run is set';
  throws_ok { npg::samplesheet->new(
    run => $schema->resultset('Run')->find(26487), lims => \@lims, extend => 1)->process() 
  } qr/Run data set \(id_run or run\) where LIMs data are for multiple runs/,
    'error if run object is set';

  throws_ok { npg::samplesheet->new(lims => \@lims, npg_tracking_schema=>$schema, extend => 0)->process() }
    qr/id_run or a run is required/,
    'error trying to generate a default samplesheet';
  throws_ok { npg::samplesheet->new(lims => \@lims, npg_tracking_schema=>$schema)->process() }
    qr/id_run or a run is required/,
    'error trying to generate a default samplesheet';

  my $result = q();
  my $ss = npg::samplesheet->new(extend => 1, lims => \@lims, output=> \$result);
  lives_ok { $ss->process() } 'processed without any error';
  ok ($ss->_add_id_run_column, 'flag for id_run column is set');
  is_string($result, read_file($path));
};

1;
