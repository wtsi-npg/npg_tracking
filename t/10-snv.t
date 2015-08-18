use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;
use File::Basename;

my $repos = 't/data/repos1';
local $ENV{NPG_WEBSERVICE_CACHE_DIR} = $repos;

use_ok('npg_tracking::data::snv');
{
  my $test = npg_tracking::data::snv->new ( id_run => 7753, position => 1, tag_index => 2, repository => $repos);
  isa_ok($test, 'npg_tracking::data::snv');
  like($test->snv_repository, qr/t\/data\/repos1\/population_snv$/, 'svn repository path is correct');
  lives_and { is basename($test->snv_file), 'Human_all_exon_50MB-1000Genomes_hs37d5.vcf.gz' } 'snv file found';

  $test = npg_tracking::data::snv->new ( id_run => 7754, position => 1, tag_index => 2, repository => $repos);
  is basename($test->snv_file), 'Human_all_exon_50MB-1000Genomes_hs37d5.vcf.gz' , 'snv file found with no bait';

  $test = npg_tracking::data::snv->new ( id_run => 7753, position => 1, tag_index => 5, repository => $repos);
  is($test->lims->reference_genome, 'Not suitable for alignment', 'no reference defined');
  is($test->snv_path, undef, 'snv path undefined');
  is($test->snv_file, undef, 'snv file undefined');
  is($test->messages->pop, 'Failed to get svn_path', 'correct message saved');
}

1;


