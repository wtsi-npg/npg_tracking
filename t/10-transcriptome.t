use strict;
use warnings;
use Test::More tests => 17;
use File::Basename;
use File::Spec::Functions qw(catfile);
use Test::Exception;
use File::Temp qw/ tempdir /;
use File::Path qw/make_path/;
use File::chdir;
use File::Copy;
use Cwd;
use Carp;
use IO::File;

use st::api::lims;

my $repos = 't/data/repos1';

use_ok('npg_tracking::data::transcriptome');

{
my $tmp_repos = tempdir( CLEANUP => 1);
local $ENV{NPG_WEBSERVICE_CACHE_DIR} = $tmp_repos;

my %builds = ();
   $builds{'Homo_sapiens'} = ['1000Genomes_hs37d5','CGP_GRCh37.NCBI.allchr_MT','GRCh37_53'];
   $builds{'Mus_musculus'} = ['GRCm38','NCBIm37','std_unmasked_NCBIm37'];

my $dir = join q[/],$tmp_repos,'transcriptomes';

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

       #symlink_default($dir,$spp,'ensembl_75_transcriptome');

}

my $batch_dir   = join q[/],'st','batches';
my $samples_dir = join q[/],'st','samples';
my $study_dir   = join q[/],'st','studies';

make_path ("$tmp_repos/$batch_dir","$tmp_repos/$samples_dir","$tmp_repos/$study_dir",{verbose => 0}); #to create directory tree

#Mouse 
copy("$repos/$batch_dir/25539.xml","$tmp_repos/$batch_dir/25539.xml") or carp "Copy failed: $!";
copy("$repos/$samples_dir/1807468.xml","$tmp_repos/$samples_dir/1807468.xml") or carp "Copy failed: $!";
#Human
copy("$repos/$batch_dir/25715.xml","$tmp_repos/$batch_dir/25715.xml") or carp "Copy failed: $!";
copy("$repos/$samples_dir/1830658.xml","$tmp_repos/$samples_dir/1830658.xml") or carp "Copy failed: $!";
copy("$repos/$study_dir/2910.xml","$tmp_repos/$study_dir/2910.xml") or carp "Copy failed: $!";

#make directory structure with empty files
my @files = ();
$files[0] = join(q[/], $dir, 'Mus_musculus','ensembl_75_transcriptome', 'GRCm38','gtf','ensembl_75_transcriptome-GRCm38.gtf');

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

#make directory structure with empty files and funny business (multiple files, missing files, etc)
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
###########################################################################################################################

#Mus_musculus (GRCm38 + ensembl_75_transcriptome)  Transcriptome Analysis
my %init = (id_run => 12071, position => 4, tag_index => 2);
my $m_test = npg_tracking::data::transcriptome->new (%init,
  lims => st::api::lims->new(%init, batch_id => 25539, driver_type => 'xml'),
  repository => $tmp_repos, aligner => 'tophat2');
isa_ok($m_test, 'npg_tracking::data::transcriptome');
lives_and { is basename($m_test->gtf_file), 'ensembl_75_transcriptome-GRCm38.gtf' } 'file ensembl_75_transcriptome-GRCm38.gtf found';

#Homo_sapiens (1000Genomes_hs37d5)
%init = (id_run => 12161, position => 1, tag_index => 1);
my $test = npg_tracking::data::transcriptome->new (%init,
  lims => st::api::lims->new(%init, batch_id => 25715, driver_type => 'xml'),
  repository => $tmp_repos);

lives_and { is $test->transcriptome_index_path,undef } "ok - returns undef for transcriptome_index_path if no transcriptome version in reference name - Homo_sapiens (1000Genomes_hs37d5)";

##update sample xml so that Reference Genome is missing (study 2910.xml already has this field empty)
copy("$tmp_repos/$samples_dir/1830658.xml", "$tmp_repos/$samples_dir/1830658.xml.1") or carp "Copy failed: $!";
my $fh = IO::File->new("<$tmp_repos/$samples_dir/1830658.xml.1") or carp "cannot open $repos/$samples_dir/1830658.xml.1";
my $w_fh = IO::File->new(">$tmp_repos/$samples_dir/1830658.xml") or carp "cannot open $repos/$samples_dir/1830658.xml";
while(<$fh>){
       if (/Homo_sapiens\s+(\S+)/){
          print $w_fh " " x 6 . "<value></value>\n";
       }      
       else { print $w_fh $_ }
}
$w_fh->close;
$fh->close;

%init = (id_run => 12161, position => 1, tag_index => 1);
my $test2 = npg_tracking::data::transcriptome->new (%init,
  lims => st::api::lims->new(%init, batch_id => 25715, driver_type => 'xml'),
  repository => $tmp_repos);
lives_and { is $test2->transcriptome_index_path, undef } "no path for bowtie2 indices found (reference genome missing in sample and study xml)";


##update sample xml so that Reference Genome has a transcriptome version : Homo_sapiens (1000Genomes_hs37d5 + ensembl_74_transcriptome)

my $ver_fh = IO::File->new("<$tmp_repos/$samples_dir/1830658.xml.1") or carp "cannot open $repos/$samples_dir/1830658.xml.1";
my $ver_w_fh = IO::File->new(">$tmp_repos/$samples_dir/1830658.xml") or carp "cannot open $repos/$samples_dir/1830658.xml";
while(<$ver_fh>){
       if (/Homo_sapiens\s+(\S+)/){
          print $ver_w_fh " " x 6 . "<value>Homo_sapiens (1000Genomes_hs37d5 + ensembl_74_transcriptome)</value>\n";
       }      
       else { print $ver_w_fh $_ }
}
$ver_w_fh->close;
$ver_fh->close;

%init = (id_run => 12161, position => 1, tag_index => 1);
my $test3 = npg_tracking::data::transcriptome->new (%init,
  lims => st::api::lims->new(%init, batch_id => 25715, driver_type => 'xml'),
  repository => $tmp_repos);
lives_and { is basename($test3->gtf_file), 'ensembl_74_transcriptome-1000Genomes_hs37d5.gtf' } 'file ensembl_74_transcriptome-1000Genomes_hs37d5.gtf found where reference = Homo_sapiens (1000Genomes_hs37d5 + ensembl_74_transcriptome)';

lives_and { is basename($test3->rnaseqc_gtf_file), 'ensembl_74_transcriptome-1000Genomes_hs37d5.gtf' } 'RNA-SeQC file ensembl_74_transcriptome-1000Genomes_hs37d5.gtf found where reference = Homo_sapiens (1000Genomes_hs37d5 + ensembl_74_transcriptome)';

lives_and { is $test3->transcriptome_index_path, catfile($tmp_repos, q[transcriptomes/Homo_sapiens/ensembl_74_transcriptome/1000Genomes_hs37d5/tophat2])
} "correct path for bowtie2 indices found";

lives_and { is basename($test3->globin_file), 'globin_genes.csv' } 'globin genes csv file found where reference = Homo_sapiens (1000Genomes_hs37d5 + ensembl_74_transcriptome)';

lives_and { is basename($test3->mt_file), 'mt_genes.csv' } 'mt genes csv file found where reference = Homo_sapiens (1000Genomes_hs37d5 + ensembl_74_transcriptome)';

my $prefix_path_74 = catfile($tmp_repos, q[transcriptomes/Homo_sapiens/ensembl_74_transcriptome/1000Genomes_hs37d5/tophat2/1000Genomes_hs37d5.known]);
lives_and { is $test3->transcriptome_index_name, $prefix_path_74 } "Correctly found transcriptome version index name path and prefix ";

my $test4 = npg_tracking::data::transcriptome->new (
  %init, repository => $tmp_repos,
  lims => st::api::lims->new(%init, batch_id => 25715, driver_type => 'xml'),
  aligner => 'tophat2', analysis => 'salmon');
lives_and { is $test4->transcriptome_index_path, catfile($tmp_repos, q[transcriptomes/Homo_sapiens/ensembl_74_transcriptome/1000Genomes_hs37d5/salmon])
} "correct path for salmon indices found";

lives_and { is $test4->transcriptome_index_name, undef
} "ok - returns undef when looking for index name for salmon";

my $test5 = npg_tracking::data::transcriptome->new (
  %init, repository => $tmp_repos,
  lims => st::api::lims->new(%init, batch_id => 25715, driver_type => 'xml')
);
lives_and { is basename($test5->fasta_file), '1000Genomes_hs37d5.fa'
} "transcriptome fasta file 1000Genomes_hs37d5.fa found where reference = Homo_sapiens (1000Genomes_hs37d5 + ensembl_74_transcriptome)";


##update sample xml so that Reference Genome has a transcriptome version : Mus_musculus (GRCm38 + ensembl_84_transcriptome)
copy("$tmp_repos/$samples_dir/1807468.xml", "$tmp_repos/$samples_dir/1807468.xml.1") or carp "Copy failed: $!";
my $cpy_fh = IO::File->new("<$tmp_repos/$samples_dir/1807468.xml.1") or carp "cannot open $repos/$samples_dir/1807468.xml.1";
my $mm_ver_fh = IO::File->new(">$tmp_repos/$samples_dir/1807468.xml") or carp "cannot open $repos/$samples_dir/1807468.xml";
while(<$cpy_fh>){
    if (/Mus_musculus\s+(\S+)/){
        print $mm_ver_fh " " x 6 . "<value>Mus_musculus (GRCm38 + ensembl_84_transcriptome)</value>\n";
    }
    else { print $mm_ver_fh $_ }
}
$mm_ver_fh->close;
$cpy_fh->close;

%init = (id_run => 12071, position => 4, tag_index => 2);
my $test6 = npg_tracking::data::transcriptome->new (
  %init, repository => $tmp_repos,
  lims => st::api::lims->new(%init, batch_id => 25539, driver_type => 'xml'));
throws_ok { $test6->gtf_file } qr/More than one gtf file/,
'ok - croaks when more than 1 gtf file found - Mus_musculus (GRCm38 + ensembl_84_transcriptome)';

my $prefix_path_84 = catfile($tmp_repos, q[transcriptomes/Mus_musculus/ensembl_84_transcriptome/GRCm38/tophat2/GRCm38.known]);
my $re_no_idx_name = qr/^Directory.*exists.*index.*files.*not.*found.*$/msxi;
my $empty_idx_name = $test6->transcriptome_index_name;
lives_and { is $empty_idx_name, undef } "ok - returns undef for transcriptome_index_name if index files are not present - Mus_musculus (GRCm38 + ensembl_84_transcriptome)";
my ($tmsg, $msg);
$tmsg = $test6->messages()->mlist;
foreach my $m (@{$tmsg}){ $msg = $m; last if ($msg =~ /$re_no_idx_name/); }
like($msg, $re_no_idx_name, 'ok - message stored when index files not found');

}

# make default symlink 
sub symlink_default {
    my($dir,$spp,$release) = @_;
    my $orig_dir = getcwd();
    my $rel_dir = join q[/],$dir,$spp;
    chdir qq[$rel_dir];
    eval { symlink($release,"default") };
    print "symlink error $@" if $@; 
    chdir $orig_dir;
    return;
}
