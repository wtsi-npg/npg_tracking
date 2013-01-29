use strict;
use warnings;
use Test::More tests => 12;
use Test::Exception;
use Moose::Meta::Class;

my $repos = 't/data/repos1';
my $baits_repos = 't/data/repos1/baits';

{
  local $ENV{http_proxy} = 'wibble';
  use_ok('npg_tracking::data::bait::find');
  my $fb;
  lives_ok { $fb = Moose::Meta::Class->create_anon_class(
         roles => [qw/npg_tracking::data::bait::find/])
         ->new_object({ repository     => $repos,
                        bait_name      => 'Human_all_exon_50MB',
                        species        => 'Homo_sapiens',
                        strain         => '1000Genomes_hs37d5',
                      }) }
     'no error creating an object without id_run and position accessors';
  is($fb->bait_path, "$baits_repos/Human_all_exon_50MB/1000Genomes_hs37d5", 'bait path bipassing lims object');
}

{
  my $fb = Moose::Meta::Class->create_anon_class(
         roles => [qw/npg_tracking::data::bait::find/])
         ->new_object({ repository     => $repos . q[/],
                        bait_name      => 'Human_all_exon_50MB',
                        species        => 'Homo_sapiens',
                        strain         => '1000Genomes_hs37d5',
                      });
  is($fb->bait_path, "$baits_repos/Human_all_exon_50MB/1000Genomes_hs37d5", 'bait path bipassing lims object');
}

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/repos1';
#local $ENV{SAVE2NPG_WEBSERVICE_CACHE} = 1;
use_ok('npg_tracking::data::bait');
{ # This id_run, position, tag_index should return valid results
  my $test = npg_tracking::data::bait->new ( id_run => 7753, position => 1, tag_index => 2, repository => $repos);
  isa_ok($test, 'npg_tracking::data::bait');
  lives_and { is $test->bait_path, "$baits_repos/Human_all_exon_50MB/1000Genomes_hs37d5" } ' bait path found';
  is($test->bait_intervals_path, "$baits_repos/Human_all_exon_50MB/1000Genomes_hs37d5/S02972011-GRCh37_hs37d5-CTR.interval_list", 
    'bait CTR file found');
  is($test->target_intervals_path, "$baits_repos/Human_all_exon_50MB/1000Genomes_hs37d5/S02972011-GRCh37_hs37d5-PTR.interval_list", 
    'bait PTR file found');
}

{ # There is no bait name or files for this run
  my $test =npg_tracking::data::bait->new( repository => $repos, id_run => 7754, position => 1, tag_index => 2);
  lives_and { is $test->bait_path, undef } ' bait path found';
  is($test->bait_intervals_path, undef, 'bait CTR file found');
  is($test->target_intervals_path, undef, 'bait PTR file found');
}

1;


