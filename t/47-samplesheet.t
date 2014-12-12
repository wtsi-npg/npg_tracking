use strict;
use warnings;
use Test::More tests => 50;
use Test::LongString;
use Test::Exception;
use File::Slurp;
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;

use t::dbic_util;
local $ENV{dev} = q(wibble); # ensure we're not going live anywhere

use_ok('npg::samplesheet');

my $schema = t::dbic_util->new->test_schema();
local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q(t/data/samplesheet);

my $dir = tempdir( CLEANUP => 1 );
my @refs = ();

foreach my $r (qw(PhiX/Illumina
                  Homo_sapiens/NCBI36
                  Mus_musculus/NCBIm37
                  Strongyloides_ratti/20100601
                  Salmonella_pullorum/449_87
                  Homo_sapiens/1000Genomes
                  Haemonchus_contortus/V1_21June13
                  Plasmodium_falciparum/3D7
                  Bordetella_pertussis/ST24
                  Mus_musculus/GRCm38
                  Homo_sapiens/GRCh37_53
                  Homo_sapiens/CGP_GRCh37.NCBI.allchr_MT)) {

  my $path = "$dir/references/$r/all/fasta";
  make_path $path;
  push @refs, $path;
}

use Cwd;
my $current = getcwd();
make_path "$dir/references/taxon_ids";
chdir "$dir/references/taxon_ids";
symlink "../Homo_sapiens", "9606";
chdir $current;
symlink "$dir/references/Homo_sapiens/NCBI36", "$dir/references/Homo_sapiens/default";
symlink "$dir/references/PhiX/Illumina", "$dir/references/PhiX/default";

foreach my $r (@refs) {
  my $file = "$r/some.fa";
  open my $fh, '>', $file or die "Cannot write to $file";
  print $fh 'some ref';
  close $fh;
}

{
  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>7826, output=>\$result); } 'sample sheet object for dual index';
  my $expected_result = << 'RESULT_7826';
[Header],,,,
Investigator Name,nh4,,,
Project Name,Mate Pair R%26D,,,
Experiment Name,7826,,,
Date,2012-04-03T16:39:48,,,
Workflow,LibraryQC,,,
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
4894529,Mouse_test_3kb,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Mus_musculus\NCBIm37\all\fasta\,ATCACGTT,ATAAAAAA,
4894528,Tetse_3kb,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\PhiX\Illumina\all\fasta\,CGATGTTT,ATTTTTTT,
4894527,PfIT_454_5kb,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Plasmodium_falciparum\3D7\all\fasta\,ACTTGATG,ATCCCCCC,
4894525,PfIT_Sanger_5kb,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Plasmodium_falciparum\3D7\all\fasta\,GATCAGCG,ATGGGGGG,
4894526,PfIT_SOLiD5500_5kb,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Plasmodium_falciparum\3D7\all\fasta\,TAGCTTGT,ATACACGT,
RESULT_7826
  $expected_result =~ s/\n/\r\n/smg;
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, $expected_result, 'Dual indexes created');
}


{
  my $ss;
  my $result = q();
  dies_ok { $ss = npg::samplesheet->new( repository=>$dir, output=>\$result)->process; } 'sample sheet process fails when no run object nor id_run given';
}

my $expected_result_7007 = << 'RESULT_7007';
[Header],,,
Investigator Name,mq1,,
Project Name,Strongyloides ratti transcriptomics,,
Experiment Name,7007,,
Date,2011-11-03T12:16:00,,
Workflow,LibraryQC,,
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
3789277,Strongyloides ratti,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Strongyloides_ratti\20100601\all\fasta\,
RESULT_7007
$expected_result_7007 =~ s/\n/\r\n/smg;
{
  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>7007, output=>\$result); } 'sample sheet object for unplexed paired run';
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, $expected_result_7007);
}
{
  my $run = $schema->resultset(q(Run))->find(7007);
  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, run=>$run, output=>\$result); } 'sample sheet object from run object - no id_run given';
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, $expected_result_7007);
}


{
  my $ss;
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>7007); } 'sample sheet object - no output provided';
  cmp_ok($ss->output, 'eq', '/nfs/sf49/ILorHSorMS_sf49/samplesheets/wibble/MS0001309-300.csv', 'default output location (with zeroes trimmed appropriately)');
}
{
  my $ss;
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>7007); } 'sample sheet object - no output provided';
  my $orig_flowcell_id = $ss->run->flowcell_id;
  $ss->run->flowcell_id(q(MS2000132-500V2));
  cmp_ok($ss->output, 'eq', '/nfs/sf49/ILorHSorMS_sf49/samplesheets/wibble/MS2000132-500V2.csv', 'default output location copes with V2 MiSeq cartirdges/reagent kits');
  $ss->run->flowcell_id($orig_flowcell_id);
}
{
  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946, output=>\$result); } 'sample sheet object for plexed paired run';
  my $expected_result = << 'RESULT_6946';
[Header],,,,
Investigator Name,mq1,,,
Project Name,Kapa HiFi test,,,
Experiment Name,6946,,,
Date,2011-10-14T16:32:00,,,
Workflow,LibraryQC,,,
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
3789278,Salmonella pullorum,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Salmonella_pullorum\449_87\all\fasta\,ATCACGTT,
3789279,Bordetella Pertussis,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Bordetella_pertussis\ST24\all\fasta\,CGATGTTT,
3789280,Plasmodium Falciparum,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Plasmodium_falciparum\3D7\all\fasta\,TTAGGCAT,
3789281,Homo sapiens,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Homo_sapiens\GRCh37_53\all\fasta\,TGACCACT,
3789282,Salmonella pullorum,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Salmonella_pullorum\449_87\all\fasta\,ACAGTGGT,
3789283,Bordetella Pertussis,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Bordetella_pertussis\ST24\all\fasta\,GCCAATGT,
3789284,Plasmodium Falciparum,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Plasmodium_falciparum\3D7\all\fasta\,CAGATCTG,
3789285,Homo sapiens,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Homo_sapiens\GRCh37_53\all\fasta\,ACTTGATG,
3789286,Salmonella pullorum,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Salmonella_pullorum\449_87\all\fasta\,GATCAGCG,
3789287,Bordetella Pertussis,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Bordetella_pertussis\ST24\all\fasta\,TAGCTTGT,
3789288,Plasmodium Falciparum,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Plasmodium_falciparum\3D7\all\fasta\,GGCTACAG,
3789289,Homo sapiens,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Homo_sapiens\GRCh37_53\all\fasta\,CTTGTACT,
RESULT_6946
  $expected_result =~ s/\n/\r\n/smg;
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, $expected_result);
}
{
  my $ss;
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946); } 'sample sheet object - no output provided';
  cmp_ok($ss->output, 'eq', '/nfs/sf49/ILorHSorMS_sf49/samplesheets/wibble/000000000-A0616.csv', 'default output location')
}
{
  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>7825, output=>\$result); } 'sample sheet object for plexed paired run';
  my $expected_result = << 'RESULT_7825';
[Header],,,,
Investigator Name,nh4,,,
Project Name,Mate Pair R%26D,,,
Experiment Name,7825,,,
Date,2012-04-03T16:39:48,,,
Workflow,LibraryQC,,,
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
4894529,Mouse_test_3kb,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Mus_musculus\NCBIm37\all\fasta\,ATCACGTTAT,
4894528,Tetse_3kb,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\PhiX\Illumina\all\fasta\,CGATGTTTAT,
4894527,PfIT_454_5kb,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Plasmodium_falciparum\3D7\all\fasta\,ACTTGATGAT,
4894525,PfIT_Sanger_5kb,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Plasmodium_falciparum\3D7\all\fasta\,GATCAGCGAT,
4894526,PfIT_SOLiD5500_5kb,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Plasmodium_falciparum\3D7\all\fasta\,TAGCTTGTAT,
RESULT_7825
  $expected_result =~ s/\n/\r\n/smg;
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, $expected_result, 'PhiX used as fall back reference');
}

{
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
}

{
  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, extend => 1, id_run=>7007, output=>\$result); } 'extended sample sheet object for unplexed paired run';
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, read_file('t/data/samplesheet/7007_extended.csv'));
}

{
  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946, extend => 1, output=>\$result); } 'extended sample sheet object for plexed paired run';
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, read_file('t/data/samplesheet/6946_extended.csv'));
}

{
  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/test45];
  # assign batch_id for run 3905 - one control lane and 7 libraries
  $schema->resultset('Run')->find(6946)->update({batch_id => 4775,});

  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946, extend => 1, output=>\$result); }
    'extended sample sheet object for unplexed paired 8 lane run with a control lane';
  lives_ok { $ss->process(); } 'sample sheet generated';
  is_string($result, read_file('t/data/samplesheet/1control7libs_extended.csv'));
}

{
  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/test45];
  # assign batch_id for run 7690 - 8 pools
  $schema->resultset('Run')->find(6946)->update({batch_id => 16249,});

  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946, extend => 1, output=>\$result); }
    'extended sample sheet object for plexed paired 8 lane run';
  lives_ok { $ss->process(); } 'sample sheet generated';
  is_string($result, read_file('t/data/samplesheet/8pools_extended.csv'));
}

{
  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/samplesheet];
  $ENV{dev} = 'live';
  # assign batch_id for run 11114 - 4 pools 4 libs
  $schema->resultset('Run')->find(6946)->update({batch_id => 23798,});

  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(repository=>$dir, npg_tracking_schema=>$schema, id_run=>6946, extend => 1, output=>\$result); }
    'extended sample sheet object for plexed paired run with both pool and library lanes';
  lives_ok { $ss->process(); } 'sample sheet generated';
  is_string($result, read_file('t/data/samplesheet/4pool4libs_extended.csv'));
}

1;
