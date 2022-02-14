use strict;
use warnings;
use Test::More tests => 12;
use Test::Exception;
use File::Basename;

use st::api::lims;

my $repos = 't/data/repos1';

use_ok('npg_tracking::data::snv');

{
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/samplesheet/samplesheet_7753.csv';
  my %init = (id_run => 7753, position => 1, tag_index => 2);
  my $test = npg_tracking::data::snv->new (%init, repository => $repos,
    lims => st::api::lims->new(%init));
  isa_ok($test, 'npg_tracking::data::snv');
  like($test->snv_repository, qr/t\/data\/repos1\/population_snv$/, 'svn repository path is correct');
  lives_and { is basename($test->snv_file), 'Human_all_exon_50MB-1000Genomes_hs37d5.vcf.gz' } 'snv file found';

  %init = (id_run => 7754, position => 1, tag_index => 2);
  $test = npg_tracking::data::snv->new (%init, repository => $repos,
    lims => st::api::lims->new(%init));
  is basename($test->snv_file), 'Human_all_exon_50MB-1000Genomes_hs37d5.vcf.gz' , 'snv file found with no bait';

  %init = (id_run => 7753, position => 1, tag_index => 5);
  $test = npg_tracking::data::snv->new (%init, repository => $repos,
    lims => st::api::lims->new(%init));
  is($test->lims->reference_genome, 'Not suitable for alignment', 'no reference defined');
  is($test->snv_path, undef, 'snv path undefined');
  is($test->snv_file, undef, 'snv file undefined');
  is($test->messages->pop, 'Failed to get svn_path', 'correct message saved');
}

{
  local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} = q[t/data/samplesheet/samplesheet_27483.csv];
  my $test = npg_tracking::data::snv->new ( id_run => 27483, position => 1, tag_index => 1, repository => $repos);
  is($test->bait_name, undef, q[bait name undefined for RNA library]);
  my $expected_bait_name = q[Exome];
  my $expected_snv_path = qr[$repos/population_snv/Homo_sapiens/default/$expected_bait_name/GRCh38_15];
  my $expected_snv_file = q[test.vcf.gz];
  like($test->snv_path, $expected_snv_path, qq[snv path for RNA library is correct]);
  lives_and {is basename($test->snv_file), $expected_snv_file, q[snv file for RNA library is correct]};
}

1;


