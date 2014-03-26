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

my $repos = 't/data/repos1';

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/repos1';

use_ok('npg_tracking::data::transcriptome');

{

##  12161_1#1 t/data/repos1/npg/run/12161.xml t/data/repos1/st/batches/25715.xml   t/data/repos1/st/samples/1830658.xml  
 my $test = npg_tracking::data::transcriptome->new (id_run => 12161, position => 1, tag_index => 1, repository => $repos);
    isa_ok($test, 'npg_tracking::data::transcriptome');
    lives_and { is basename($test->gtf_file), 'ensembl_release_75-1000Genomes_hs37d5.gtf' } 'gtf file found';

 my $gtf_path = strip_path_start($test->gtf_path); 
    lives_and { is $gtf_path, catfile($repos, q[transcriptomes/Homo_sapiens/ensembl_release_75/1000Genomes_hs37d5/gtf])} "correct path for gtf file found";

 my $index_path = strip_path_start($test->transcriptome_index_path);

    lives_and { is $index_path, catfile($repos, q[transcriptomes/Homo_sapiens/ensembl_release_75/1000Genomes_hs37d5/tophat2])
} "correct path for bowtie2 indices found";

 my $index_name = strip_path_start($test->transcriptome_index_name);
 my $prefix_path = catfile($repos, q[transcriptomes/Homo_sapiens/ensembl_release_75/1000Genomes_hs37d5/tophat2/1000Genomes_hs37d5.known]);

    lives_and { is $index_name,$prefix_path } "correct index name path and prefix : $prefix_path ";

}

sub strip_path_start {
    my $path = shift;
       $path =~ s/(\S+)\/t\/data/t\/data/;
    return($path);
}
