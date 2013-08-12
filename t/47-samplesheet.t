#########
# Author:        dj3
# Maintainer:    $Author: mg8 $
# Created:       2011-11-10
# Last Modified: $Date: 2011-09-09 14:59:49 +0100 (Fri, 09 Sep 2011) $
# Id:            $Id: 14-dbic-Run.t 14155 2011-09-09 13:59:49Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/branches/prerelease-63.0/t/14-dbic-Run.t $

use strict;
use warnings;

use English qw(-no_match_vars);

use Test::More tests => 20;
use Test::LongString;
use Test::Exception;

use t::dbic_util;
local $ENV{dev} = q(wibble); # ensure we're not going live anywhere

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 14155 $ =~ /(\d+)/msx; $r; };

use_ok('npg::samplesheet');

my $schema = t::dbic_util->new->test_schema();
local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q(t/data/samplesheet);

{
  my $ss;
  my $result = q();
  dies_ok { $ss = npg::samplesheet->new(output=>\$result)->process; } 'sample sheet process fails when no run object nor id_run given';
}

my $expected_result_7007 = << 'RESULT_7007';
[Header],,,,
Investigator Name,mq1,,,
Project Name,Strongyloides ratti transcriptomics,,,
Experiment Name,7007,,,
Date,2011-11-03T12:16:00,,,
Workflow,LibraryQC,,,
Chemistry,Default,,,
,,,,
[Reads],,,,
150,,,,
150,,,,
,,,,
[Settings],,,,
,,,,
[Manifests],,,,
,,,,
[Data],,,,
Sample_ID,Sample_Name,GenomeFolder,,
3789277,Strongyloides ratti,C:\Illumina\MiSeq Reporter\Genomes\WTSI_references\Strongyloides_ratti\20100601\all\fasta\,,
RESULT_7007
$expected_result_7007 =~ s/\n/\r\n/smg;
{
  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(npg_tracking_schema=>$schema, id_run=>7007, output=>\$result); } 'sample sheet object for unplexed paired run';
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, $expected_result_7007);
}
{
  my $run = $schema->resultset(q(Run))->find(7007);
  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(run=>$run, output=>\$result); } 'sample sheet object from run object - no id_run given';
  lives_ok { $ss->process(); } ' sample sheet generated';
  is_string($result, $expected_result_7007);
}


{
  my $ss;
  lives_ok { $ss = npg::samplesheet->new(npg_tracking_schema=>$schema, id_run=>7007); } 'sample sheet object - no output provided';
  cmp_ok($ss->output, 'eq', '/nfs/sf49/ILorHSorMS_sf49/samplesheets/wibble/MS0001309-300.csv', 'default output location (with zeroes trimmed appropriately)');
}
{
  my $ss;
  lives_ok { $ss = npg::samplesheet->new(npg_tracking_schema=>$schema, id_run=>7007); } 'sample sheet object - no output provided';
  my $orig_flowcell_id = $ss->run->flowcell_id;
  $ss->run->flowcell_id(q(MS2000132-500V2));
  cmp_ok($ss->output, 'eq', '/nfs/sf49/ILorHSorMS_sf49/samplesheets/wibble/MS2000132-500V2.csv', 'default output location copes with V2 MiSeq cartirdges/reagent kits');
  $ss->run->flowcell_id($orig_flowcell_id);
}
{
  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(npg_tracking_schema=>$schema, id_run=>6946, output=>\$result); } 'sample sheet object for plexed paired run';
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
  lives_ok { $ss = npg::samplesheet->new(npg_tracking_schema=>$schema, id_run=>6946); } 'sample sheet object - no output provided';
  cmp_ok($ss->output, 'eq', '/nfs/sf49/ILorHSorMS_sf49/samplesheets/wibble/000000000-A0616.csv', 'default output location')
}
{
  my $ss;
  my $result = q();
  lives_ok { $ss = npg::samplesheet->new(npg_tracking_schema=>$schema, id_run=>7825, output=>\$result); } 'sample sheet object for plexed paired run';
  my $expected_result = << 'RESULT_7825';
[Header],,,,
Investigator Name,nh4,,,
Project Name,Mate Pair R&D,,,
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


