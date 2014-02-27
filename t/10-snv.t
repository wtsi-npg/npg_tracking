use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use Moose::Meta::Class;
use File::Basename;

my $repos = 't/data/repos1';
my $snv_repos = 't/data/repos1/population_snv';

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/repos1';

use_ok('npg_tracking::data::snv');
{ # This id_run, position, tag_index should return valid results
  my $test = npg_tracking::data::snv->new ( id_run => 7753, position => 1, tag_index => 2, repository => $repos);
  isa_ok($test, 'npg_tracking::data::snv');
  lives_and { is basename($test->snv_file), 'Human_all_exon_50MB-1000Genomes_hs37d5.vcf.gz' } 'snv file found';

}

1;


