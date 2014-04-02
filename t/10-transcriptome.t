#################
# Author:        Jillian Durham 
# Maintainer:    $Author$
# Created:       March 2014 
# Last Modified: $Date$
# Id:            $Id$
# $HeadURL$

package transcriptome;

use strict;
use warnings;
use Test::More tests => 6;
use File::Basename;
use File::Spec::Functions qw(catfile);
use Test::Exception;
use File::Temp qw/ tempdir /;
use File::Path qw/make_path/;
use File::chdir;
use File::Copy;
use Cwd;

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
        my $rel_dir1 = join q[/],$dir,$spp,'ensembl_release_75';
        my $rel_dir2 = join q[/],$dir,$spp,'ensembl_release_74';
        make_path($rel_dir2,{verbose => 0});
        symlink_default($dir,$spp,'ensembl_release_75');
        foreach my $build (@{ $builds{$spp} }){
          my $gtf_dir    = join q[/],$rel_dir1,$build,'gtf';
          my $tophat_dir = join q[/],$rel_dir1,$build,'tophat2';
          make_path($gtf_dir,$tophat_dir,{verbose => 0});
        }

}

my $run_dir     = join q[/],'npg','run';
my $batch_dir   = join q[/],'st','batches';
my $samples_dir = join q[/],'st','samples';

make_path ("$tmp_repos/$run_dir","$tmp_repos/$batch_dir","$tmp_repos/$samples_dir",{verbose => 0}); #to create directory tree

#Mouse 
copy("$repos/$run_dir/12071.xml","$tmp_repos/$run_dir/12071.xml") or die "Copy failed: $!";
copy("$repos/$batch_dir/25539.xml","$tmp_repos/$batch_dir/25539.xml") or die "Copy failed: $!";
copy("$repos/$samples_dir/1807468.xml","$tmp_repos/$samples_dir/1807468.xml") or die "Copy failed: $!";
#Human
copy("$repos/$run_dir/12161.xml","$tmp_repos/$run_dir/12161.xml") or die "Copy failed: $!";
copy("$repos/$batch_dir/25715.xml","$tmp_repos/$batch_dir/25715.xml") or die "Copy failed: $!";
copy("$repos/$samples_dir/1830658.xml","$tmp_repos/$samples_dir/1830658.xml") or die "Copy failed: $!";

my @files = ();
$files[0] = join(q[/], $dir, 'Mus_musculus','ensembl_release_75', 'GRCm38','gtf','ensembl_release_75-GRCm38.gtf');
my $h37   = join(q[/], $dir, 'Homo_sapiens','ensembl_release_75', '1000Genomes_hs37d5',);
$files[1] = join(q[/], $h37,'gtf','ensembl_release_75-1000Genomes_hs37d5.gtf');
$files[2] = join(q[/], $h37,'tophat2','1000Genomes_hs37d5.known.1.bt2');
$files[3] = join(q[/], $h37,'tophat2','1000Genomes_hs37d5.known.ver');
foreach my $file (@files){
  `touch $file`;
}


#Mus_musculus (GRCm38)  Transcriptome Analysis
my $m_test = npg_tracking::data::transcriptome->new (id_run => 12071, position => 4, tag_index => 2, repository => $tmp_repos, aligner => 'tophat2');

isa_ok($m_test, 'npg_tracking::data::transcriptome');
lives_and { is basename($m_test->gtf_file), 'ensembl_release_75-GRCm38.gtf' } 'file ensembl_release_75-GRCm38.gtf found';

#Homo_sapiens (1000Genomes_hs37d5)
my $test = npg_tracking::data::transcriptome->new (id_run => 12161, position => 1, tag_index => 1, repository => $tmp_repos);

lives_and { is basename($test->gtf_file), 'ensembl_release_75-1000Genomes_hs37d5.gtf' } 'file ensembl_release_75-1000Genomes_hs37d5.gtf found';

lives_and { is $test->transcriptome_index_path, catfile($tmp_repos, q[transcriptomes/Homo_sapiens/ensembl_release_75/1000Genomes_hs37d5/tophat2])
} "correct path for bowtie2 indices found";

my $prefix_path = catfile($tmp_repos, q[transcriptomes/Homo_sapiens/ensembl_release_75/1000Genomes_hs37d5/tophat2/1000Genomes_hs37d5.known]);

lives_and { is $test->transcriptome_index_name,$prefix_path } "correct index name path and prefix : $prefix_path ";

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
