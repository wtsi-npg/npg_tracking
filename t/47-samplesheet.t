use strict;
use warnings;
use Test::More tests => 11;
use Test::LongString;
use Test::Exception;
use File::Slurp;
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;
use Moose::Meta::Class;

use t::dbic_util;

use_ok('npg::samplesheet');
use_ok('st::api::lims');

my $schema = t::dbic_util->new->test_schema();

my $class = Moose::Meta::Class->create_anon_class(roles=>[qw/npg_testing::db/]);
my $mlwh_schema = $class->new_object({})->create_test_db(
  q[WTSI::DNAP::Warehouse::Schema], q[t/data/fixtures_lims_wh_samplesheet]
);

my $dir = tempdir( CLEANUP => 1 );

subtest 'simple tests for the default driver' => sub {
   plan tests => 1;

   my $ss = npg::samplesheet->new(
      repository          => $dir,
      npg_tracking_schema => $schema,
      mlwh_schema         => $mlwh_schema,
      id_run              => 7007
   );
   my $lims = $ss->lims();
   is (@{$lims}, 1, 'LIMS data for 1 lane is built');
};

subtest 'object creation' => sub {
  plan tests => 7;

  my $result = q();
  dies_ok { npg::samplesheet->new(mlwh_schema => $mlwh_schema,
    repository=>$dir, output=>\$result)->process }
    'samplesheet process fails when neither run object nor id_run given';

  my $ss;
  lives_ok { $ss = npg::samplesheet->new(mlwh_schema => $mlwh_schema,
    repository=>$dir, npg_tracking_schema=>$schema, id_run=>7007); }
    'samplesheet object - no output provided';
  cmp_ok($ss->output, 'eq', 'samplesheets/MS0001309-300.csv',
    'default output location (with zeroes trimmed appropriately)');

  lives_ok { $ss = npg::samplesheet->new(mlwh_schema => $mlwh_schema,
    repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946); }
    'samplesheet object - no output provided';
  cmp_ok($ss->output, 'eq', 'samplesheets/000000000-A0616.csv',
    'default output location');

  lives_ok { $ss = npg::samplesheet->new(mlwh_schema => $mlwh_schema, repository=>$dir, npg_tracking_schema=>$schema, id_run=>7007); } 'samplesheet object - no output provided';
  my $orig_flowcell_id = $ss->run->flowcell_id;
  $ss->run->flowcell_id(q(MS2000132-500V2));
  cmp_ok($ss->output, 'eq', 'samplesheets/MS2000132-500V2.csv',
    'default output location copes with V2 MiSeq cartirdges/reagent kits');
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
Workflow,GenerateFASTQ,,
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
3789277,ERS092590,,
RESULT_7007
  $expected_result_7007 =~ s/\n/\r\n/smg;

  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(mlwh_schema => $mlwh_schema,
    repository=>$dir, npg_tracking_schema=>$schema, id_run=>7007, output=>\$result); }
    'samplesheet object for unplexed paired run';
  lives_ok { $ss->process(); } ' samplesheet generated';
  is_string($result, $expected_result_7007);

  my $run = $schema->resultset(q(Run))->find(7007);
  $result = q();
  lives_ok { $ss = npg::samplesheet->new(mlwh_schema => $mlwh_schema,
    repository=>$dir, run=>$run, output=>\$result); }
    'samplesheet object from run object - no id_run given';
  lives_ok { $ss->process(); } ' samplesheet generated';
  is_string($result, $expected_result_7007);
};

subtest 'default samplesheet for a plexed paired run' => sub {
  plan tests => 3;

  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(mlwh_schema => $mlwh_schema,
    repository=>$dir, npg_tracking_schema=>$schema,
    id_run=>6946, output=>\$result); } 'samplesheet object for plexed paired run';
  my $expected_result = << 'RESULT_6946';
[Header],,,,
Investigator Name,mq1,,,
Project Name,Kapa HiFi test,,,
Experiment Name,6946,,,
Date,2011-10-14T16:32:00,,,
Workflow,GenerateFASTQ,,,
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
  lives_ok { $ss->process(); } 'samplesheet generated';
  is_string($result, $expected_result);
};

subtest 'default samplesheet for a plexed paired run with reference fallback' => sub {
  plan tests => 3;

  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(mlwh_schema => $mlwh_schema,
    repository=>$dir, npg_tracking_schema=>$schema, id_run=>7825,
    output=>\$result); } 'samplesheet object for plexed paired run';
  my $expected_result = << 'RESULT_7825';
[Header],,,,
Investigator Name,nh4,,,
Project Name,Mate Pair R%26D,,,
Experiment Name,7825,,,
Date,2012-04-03T16:39:48,,,
Workflow,GenerateFASTQ,,,
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
  lives_ok { $ss->process(); } 'samplesheet generated';
  is_string($result, $expected_result, 'PhiX used as fall-back reference');
};

subtest 'default and mkfastq samplesheets for dual index' => sub {
  plan tests => 10;

  my $run_6946 = $schema->resultset('Run')->find(6946);
  my $batch_id = $run_6946->batch_id;
  $schema->resultset('Run')->find(6946)->update({batch_id => 76873});
  my $result = q();
  my $ss;
  lives_ok { $ss = npg::samplesheet->new(mlwh_schema=>$mlwh_schema,
    repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946, output=>\$result) }
    'default samplesheet object for a dual index run';
  ok($ss->_dual_index, 'dual index from two indexes in LIMs');
  lives_ok { $ss->process(); } 'samplesheet generated';
  is_string($result, read_file('t/data/samplesheet/dual_index_default_new.csv'));

  $result = q();
  lives_ok { $ss = npg::samplesheet->new(mlwh_schema=>$mlwh_schema,
    repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946,
    mkfastq => 1, output=>\$result) } 'samplesheet object mkfastq';
  lives_ok { $ss->process(); } 'samplesheet generated';
  # With the mkfastq option we get an extra leading column, Lane.
  my @lines = map { $_ =~ s/\s\Z//g; $_ } grep { $_ =~ /\A1,/} split qq[\n], $result;
  is (scalar @lines, 32, '32 sample lines');
  is ($lines[0],
    q[1,6946_1_CGTGACACTTATTGCG,6946_1_CGTGACACTTATTGCG,,CGTGACAC,TTATTGCG,]);
  is ($lines[1],
    q[1,6946_1_ACTTAGAGCTCCATAA,6946_1_ACTTAGAGCTCCATAA,,ACTTAGAG,CTCCATAA,]);
  is ($lines[31],
    q[1,6946_1_GTAAGATGAAAGGCTG,6946_1_GTAAGATGAAAGGCTG,,GTAAGATG,AAAGGCTG,]);

  $schema->resultset('Run')->find(6946)->update({batch_id => $batch_id});
};

subtest 'extended samplesheets' => sub {
  plan tests => 16;

  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(mlwh_schema=>$mlwh_schema,
    repository=>$dir, npg_tracking_schema=>$schema, extend => 1,
    id_run=>7007, output=>\$result); }
    'extended samplesheet object for unplexed paired run';
  ok(!$ss->_dual_index, 'no dual index');
  lives_ok { $ss->process(); } 'samplesheet generated';
  is_string($result, read_file('t/data/samplesheet/7007_extended.csv'));

  $result = q();
  lives_ok { $ss = npg::samplesheet->new(mlwh_schema=>$mlwh_schema,
    repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946,
    extend => 1, output=>\$result); }
    'extended samplesheet object for plexed paired run';
  ok(!$ss->_dual_index, 'no dual index');
  lives_ok { $ss->process(); } 'samplesheet generated';
  is_string($result, read_file('t/data/samplesheet/6946_extended.csv'));

  $schema->resultset('Run')->find(6946)->update({batch_id => 23798});
  $result = q();
  lives_ok { $ss = npg::samplesheet->new(mlwh_schema=>$mlwh_schema,
    repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946,
    extend => 1, output=>\$result); }
    'extended samplesheet object for a dual index recorded as a single index';
  ok($ss->_dual_index, 'dual index from a 16 char first index');
  lives_ok { $ss->process(); } 'samplesheet generated';
  is_string($result, read_file('t/data/samplesheet/4pool4libs_extended.csv'));

  $schema->resultset('Run')->find(6946)->update({batch_id => 76873});
  $result = q();
  lives_ok { $ss = npg::samplesheet->new(mlwh_schema=>$mlwh_schema,
    repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946,
    extend => 1, output=>\$result); }
    'extended samplesheet object for a dal index run';
  ok($ss->_dual_index, 'dual index from two indexes in LIMs');
  lives_ok { $ss->process(); } 'samplesheet generated';
  is_string($result, read_file('t/data/samplesheet/dual_index_extended_new.csv'));
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
