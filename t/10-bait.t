use strict;
use warnings;
use Test::More tests => 14;
use Test::Exception;
use Moose::Meta::Class;

use st::api::lims;

my $repos = 't/data/repos1';
my $baits_repos = 't/data/repos1/baits';

use_ok('npg_tracking::data::bait::find');
use_ok('npg_tracking::data::bait');

{
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

{
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/samplesheet/samplesheet_7753.csv';

  my %ref = (id_run => 7753, position => 1, tag_index => 2);
  my $test = npg_tracking::data::bait->new(%ref, repository => $repos,
    lims => st::api::lims->new(%ref));
  isa_ok($test, 'npg_tracking::data::bait');
  lives_and { is $test->bait_path, "$baits_repos/Human_all_exon_50MB/1000Genomes_hs37d5" } 'bait path found';
  is($test->bait_intervals_path, "$baits_repos/Human_all_exon_50MB/1000Genomes_hs37d5/S02972011-GRCh37_hs37d5-CTR.interval_list",
    'bait CTR file found');
  is($test->target_intervals_path, "$baits_repos/Human_all_exon_50MB/1000Genomes_hs37d5/S02972011-GRCh37_hs37d5-PTR.interval_list",
    'bait PTR file found');

  %ref = (id_run => 7753, position => 1, tag_index => 3);
  $test = npg_tracking::data::bait->new (%ref, repository => $repos,
    lims => st::api::lims->new(%ref));
  lives_and { is $test->bait_path, "$baits_repos/Human_all_exon_50MB/1000Genomes_hs37d5" }
    'bait path found where bait name has white space around it';

  %ref = (id_run => 7753, position => 1, tag_index => 4);
  $test = npg_tracking::data::bait->new (%ref, repository => $repos,
    lims => st::api::lims->new(%ref));
  lives_and { is $test->bait_path, undef }
   'bait path not found where bait name is all white space';

  # There is no bait name for this lane
  my %ref = (id_run => 7753, position => 2, tag_index => 1);
  my $test =npg_tracking::data::bait->new(repository => $repos, %ref,
    lims => st::api::lims->new(%ref));
  lives_and { is $test->bait_path, undef } 'bait path undefined';
  is($test->bait_intervals_path, undef, 'bait CTR file undefined');
  is($test->target_intervals_path, undef, 'bait PTR file indefined');
}

1;

