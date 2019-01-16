use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use File::Basename;
use File::Copy;
use File::Find;
use File::Path qw(make_path);
use File::Spec::Functions qw(catfile catdir);
use File::Spec qw(splitpath);
use File::Temp qw(tempdir);

my $tmp_repos = tempdir(CLEANUP => 1);
local $ENV{NPG_WEBSERVICE_CACHE_DIR} = $tmp_repos;

my $ref_dir = catdir($tmp_repos,'custom_analysis','mapd','Homo_sapiens','1000Genomes_hs37d5');
`mkdir -p $ref_dir/{MappableBINS,chromosomes}`;
`touch $ref_dir/MappableBINS/Combined_Homo_sapiens_1000Genomes_hs37d5_100000_151bases_mappable_bins_GCperc_INPUT.txt`;
`touch $ref_dir/MappableBINS/Combined_Homo_sapiens_1000Genomes_hs37d5_100000_151bases_mappable_bins.bed`;
`touch $ref_dir/MappableBINS/Combined_Homo_sapiens_1000Genomes_hs37d5_500000_151bases_mappable_bins_GCperc_INPUT.txt`;
`touch $ref_dir/MappableBINS/Combined_Homo_sapiens_1000Genomes_hs37d5_500000_151bases_mappable_bins.bed`;
`touch $ref_dir/chromosomes/chr_list.txt`;

my $central = 't/data/mapd/';

use_ok('npg_tracking::data::mapd');

local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} = catfile($central, 'metadata_cache', 'samplesheet_27128.csv');

subtest 'find mapd files 1' => sub {
    plan tests => 8;

    my $test = npg_tracking::data::mapd->new(
        id_run => 27128,
        position => 1,
        tag_index => 1,
        repository => $tmp_repos,
        read_length => 151,
        bin_size => 100000,);

    isa_ok($test, 'npg_tracking::data::mapd');

    is($test->lims->reference_genome, 'Homo_sapiens (1000Genomes_hs37d5 + ensembl_75_transcriptome)',
        'reference genome ok');

    like($test->custom_analysis_repository, qr/$tmp_repos\/custom_analysis/smx,
        'custom analysis repository path is correct');

    my ($organism, $strain) = $test->parse_reference_genome($test->lims->reference_genome);
    my $mappablebins_path = catdir($tmp_repos, 'custom_analysis', 'mapd', $organism, $strain, 'MappableBINS');
    my $chromosomes_path = catdir($tmp_repos, 'custom_analysis', 'mapd', $organism, $strain, 'chromosomes');

    is($test->mappablebins_path, $mappablebins_path,
        'mappablebins path is correct');

    is($test->chromosomes_path, $chromosomes_path,
        'chromosomes path is correct');

    is(basename($test->mappability_file), 'Combined_Homo_sapiens_1000Genomes_hs37d5_100000_151bases_mappable_bins_GCperc_INPUT.txt',
        'finds mappability file');

    is(basename($test->mappability_bed_file), 'Combined_Homo_sapiens_1000Genomes_hs37d5_100000_151bases_mappable_bins.bed',
        'finds mappability bed file');

    is(basename($test->chromosomes_file), 'chr_list.txt',
        'finds chromosomes list file');
};


1;