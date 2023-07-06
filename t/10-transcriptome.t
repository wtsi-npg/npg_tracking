use strict;
use warnings;
use Test::More tests => 17;
use File::Basename;
use File::Spec::Functions qw(catfile);
use Test::Exception;
use File::Temp qw/ tempdir /;
use File::Path qw/make_path/;
use Moose::Meta::Class;

use st::api::lims;

use_ok('npg_tracking::data::transcriptome');

my $tmp_repos = tempdir( CLEANUP => 1);
my $dir = join q[/],$tmp_repos,'transcriptomes';

my %builds = ();
$builds{'Homo_sapiens'} = ['1000Genomes_hs37d5','CGP_GRCh37.NCBI.allchr_MT','GRCh37_53'];
$builds{'Mus_musculus'} = ['GRCm38','NCBIm37','std_unmasked_NCBIm37'];

foreach my $spp (keys %builds){
        
  my $rel_dir1 = join q[/],$dir,$spp,'ensembl_75_transcriptome';
  my $rel_dir2 = join q[/],$dir,$spp,'ensembl_74_transcriptome';
  my $rel_dir3 = join q[/],$dir,$spp,'ensembl_84_transcriptome';

  foreach my $rel_dir ($rel_dir1,$rel_dir2,$rel_dir3){  
    foreach my $build (@{ $builds{$spp} }){
      my $gtf_dir    = join q[/],$rel_dir,$build,'gtf'; 
      my $rnaseq_dir = join q[/],$rel_dir,$build,'RNA-SeQC';
      my $tophat_dir = join q[/],$rel_dir,$build,'tophat2';
      my $salmon_dir = join q[/],$rel_dir,$build,'salmon';
      my $fasta_dir  = join q[/],$rel_dir,$build,'fasta';
      my $globin_dir = join q[/],$rel_dir,$build,'globin';
      my $mt_dir     = join q[/],$rel_dir,$build,'mt';
      make_path($gtf_dir,
                $rnaseq_dir,
                $tophat_dir,
                $salmon_dir,
                $fasta_dir,
                $globin_dir,
                $mt_dir,
                {verbose => 0});
    }
  }
}

# Make directory structure with empty files
my @files = ();
$files[0] = join(q[/], $dir, 'Mus_musculus','ensembl_75_transcriptome',
  'GRCm38','gtf','ensembl_75_transcriptome-GRCm38.gtf');

foreach my $v ('ensembl_74_transcriptome','ensembl_75_transcriptome'){
  my $vdir = join(q[/], $dir, 'Homo_sapiens',$v, '1000Genomes_hs37d5',);
  push @files, join(q[/], $vdir,'gtf',$v . '-1000Genomes_hs37d5.gtf');
  push @files, join(q[/], $vdir,'RNA-SeQC',$v . '-1000Genomes_hs37d5.gtf');
  push @files, join(q[/], $vdir,'tophat2','1000Genomes_hs37d5.known.1.bt2');
  push @files, join(q[/], $vdir,'tophat2','1000Genomes_hs37d5.known.ver');
  push @files, join(q[/], $vdir,'salmon','versionInfo.json');
  push @files, join(q[/], $vdir,'salmon','refInfo.json');
  push @files, join(q[/], $vdir,'salmon','header.json');
  push @files, join(q[/], $vdir,'fasta','1000Genomes_hs37d5.fa');
  push @files, join(q[/], $vdir,'globin','globin_genes.csv');
  push @files, join(q[/], $vdir,'mt','mt_genes.csv');
}

# Make directory structure with empty files and funny business
# (multiple files, missing files, etc)
foreach my $v ('ensembl_84_transcriptome'){
  my $vdir = join(q[/], $dir, 'Mus_musculus',$v, 'GRCm38',);
  #more than 1 gtf present
  push @files, join(q[/], $vdir,'gtf',$v . '-GRCm38.gtf');
  push @files, join(q[/], $vdir,'gtf', 'GRCm38_sans_mt.gtf');
  #the rest of the instances are missing
}

foreach my $file (@files){
  `touch $file`;
}

my $class = Moose::Meta::Class->create_anon_class(roles=>[qw/npg_testing::db/]);
my $schema_wh = $class->new_object({})->create_test_db(
  q[WTSI::DNAP::Warehouse::Schema], q[t/data/fixtures_lims_transcriptome]
);
my %driver_info = (driver_type => 'ml_warehouse', mlwh_schema => $schema_wh);
##############################################################################


# Homo_sapiens (1000Genomes_hs37d5)
my %init = (id_run => 12161, position => 1, tag_index => 1);
my $test = npg_tracking::data::transcriptome->new (%init,
  lims => st::api::lims->new(%init, id_flowcell_lims => 25715, %driver_info),
  repository => $tmp_repos);
isa_ok($test, 'npg_tracking::data::transcriptome');
lives_and { is $test->transcriptome_index_path, undef }
  "undef for transcriptome_index_path if no transcriptome version in reference";

# Update sample data so that Reference Genome is undefined
# (study 2910 already has this field empty)
my $sample_rs = $schema_wh->resultset('Sample');
$sample_rs->search({id_sample_lims => 1830658})->next
          ->update({reference_genome => undef});
my $test2 = npg_tracking::data::transcriptome->new (%init,
  lims => st::api::lims->new(%init, id_flowcell_lims => 25715, %driver_info),
  repository => $tmp_repos);
lives_and { is $test2->transcriptome_index_path, undef }
  "no path for bowtie2 indices found (reference genome is undefined)";

# Update sample reference genome.
$sample_rs->search({id_sample_lims => 1830658})->next->update({
  reference_genome => q[Homo_sapiens (1000Genomes_hs37d5 + ensembl_74_transcriptome)]});
my $test3 = npg_tracking::data::transcriptome->new (%init,
  lims => st::api::lims->new(%init, id_flowcell_lims => 25715, %driver_info),
  repository => $tmp_repos);
lives_and { is basename($test3->gtf_file),
  'ensembl_74_transcriptome-1000Genomes_hs37d5.gtf' }
  'file ensembl_74_transcriptome-1000Genomes_hs37d5.gtf found';
lives_and { is basename($test3->rnaseqc_gtf_file),
  'ensembl_74_transcriptome-1000Genomes_hs37d5.gtf' }
  'RNA-SeQC file ensembl_74_transcriptome-1000Genomes_hs37d5.gtf found';
lives_and { is $test3->transcriptome_index_path,
  catfile($tmp_repos,
  q[transcriptomes/Homo_sapiens/ensembl_74_transcriptome/1000Genomes_hs37d5/tophat2])
} "correct path for bowtie2 indices found";
lives_and { is basename($test3->globin_file), 'globin_genes.csv' }
  'globin genes csv file found';
lives_and { is basename($test3->mt_file), 'mt_genes.csv' }
  'mt genes csv file found';
my $prefix_path_74 = catfile($tmp_repos,
  q[transcriptomes/Homo_sapiens/ensembl_74_transcriptome/1000Genomes_hs37d5/tophat2/1000Genomes_hs37d5.known]);
lives_and { is $test3->transcriptome_index_name, $prefix_path_74 }
  "Correctly found transcriptome version index name path and prefix ";

my $test4 = npg_tracking::data::transcriptome->new (
  %init, repository => $tmp_repos,
  lims => st::api::lims->new(%init, id_flowcell_lims => 25715, %driver_info),
  aligner => 'tophat2', analysis => 'salmon');
lives_and { is $test4->transcriptome_index_path, catfile($tmp_repos,
  q[transcriptomes/Homo_sapiens/ensembl_74_transcriptome/1000Genomes_hs37d5/salmon])
} "correct path for salmon indices found";
lives_and { is $test4->transcriptome_index_name, undef
} "ok - returns undef when looking for index name for salmon";

my $test5 = npg_tracking::data::transcriptome->new (
  %init, repository => $tmp_repos,
  lims => st::api::lims->new(%init, id_flowcell_lims => 25715,  %driver_info)
);
lives_and { is basename($test5->fasta_file), '1000Genomes_hs37d5.fa'
} "transcriptome fasta file 1000Genomes_hs37d5.fa found";

# Mus_musculus
%init = (id_run => 12071, position => 4, tag_index => 2);

# Update sample reference genome
$sample_rs->search({id_sample_lims => 1807468})->next->update({
  reference_genome => q[Mus_musculus (GRCm38 + ensembl_75_transcriptome)]});
my $test7 = npg_tracking::data::transcriptome->new (%init,
  lims => st::api::lims->new(%init, id_flowcell_lims => 25539, %driver_info),
  repository => $tmp_repos, aligner => 'tophat2');
lives_and { is basename($test7->gtf_file), 'ensembl_75_transcriptome-GRCm38.gtf' }
  'file ensembl_75_transcriptome-GRCm38.gtf found';

# Update sample reference genome
$sample_rs->search({id_sample_lims => 1807468})->next->update({
  reference_genome => q[Mus_musculus (GRCm38 + ensembl_84_transcriptome)]});
my $test6 = npg_tracking::data::transcriptome->new (
  %init, repository => $tmp_repos,
  lims => st::api::lims->new(%init, id_flowcell_lims => 25539, %driver_info));
throws_ok { $test6->gtf_file } qr/More than one gtf file/,
'ok - error when more than 1 gtf file found';
my $prefix_path_84 = catfile($tmp_repos,
  q[transcriptomes/Mus_musculus/ensembl_84_transcriptome/GRCm38/tophat2/GRCm38.known]);
my $re_no_idx_name = qr/^Directory.*exists.*index.*files.*not.*found.*$/msxi;
my $empty_idx_name = $test6->transcriptome_index_name;
lives_and { is $empty_idx_name, undef }
  "returns undef for transcriptome_index_name if index files are not present";
my ($tmsg, $msg);
$tmsg = $test6->messages()->mlist;
foreach my $m (@{$tmsg}){
  $msg = $m; last if ($msg =~ /$re_no_idx_name/);
}
like($msg, $re_no_idx_name, 'ok - message stored when index files not found');

1;
