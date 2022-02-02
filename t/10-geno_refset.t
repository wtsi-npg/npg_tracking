use strict;
use warnings;
use Test::More tests => 14;
use Test::Exception;
use Moose::Meta::Class;
use File::Spec::Functions qw(catdir);
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Cwd qw(cwd);
use File::Copy;
use File::Find;

use st::api::lims;

my $current_dir = cwd();
my $repos = catdir($current_dir, q[t/data/repos1]);
my $geno_repos = catdir($repos, q[geno_refset]);
my $ref_repos = catdir($repos, q[references]);

my $new = tempdir(CLEANUP => 1);

sub _copy_ref_rep {
  my $n = $File::Find::name;
  if (-d $n || -l $n) {
    return;
  }
  my ($volume,$directories,$file_name) = File::Spec->splitpath($n);
  $directories =~ s/\Q$repos\E//smx;
  $directories = $new . $directories;
  make_path $directories;
  copy $n, $directories;
}
find({'wanted' => \&_copy_ref_rep, 'follow' => 0, 'no_chdir' => 1}, $geno_repos);
find({'wanted' => \&_copy_ref_rep, 'follow' => 0, 'no_chdir' => 1}, $ref_repos);
$repos = $new;
$geno_repos = catdir($repos, q[geno_refset]);

my $species = q[Homo_sapiens];
my $strain = q[GRCh38_full_analysis_set_plus_decoy_hla];

use_ok('npg_tracking::data::geno_refset::find');
use_ok('npg_tracking::data::geno_refset');

{
  my $fb;
  lives_ok { $fb = Moose::Meta::Class->create_anon_class(
         roles => [qw/npg_tracking::data::geno_refset::find/])
         ->new_object({ repository       => $repos,
                        geno_refset_name => 'special_set',   
                        species          => $species,
                        strain           => $strain,                     
                      }) }
     'no error creating an object without id_run and position accessors';
  is($fb->geno_refset_path, qq{$geno_repos/special_set/$strain}, q{geno_refset path bypassing lims object});
}

{
  my $fb = Moose::Meta::Class->create_anon_class(
         roles => [qw/npg_tracking::data::geno_refset::find/])
         ->new_object({ repository       => $repos,
                        geno_refset_name => 'special_set',   
                        species          => $species,
                        strain           => $strain,
                        aligner          => 'fasta',                 
                      });

  is($fb->geno_refset_path, qq{$geno_repos/special_set/$strain}, q{geno_refset path bypassing lims object});

  is($fb->geno_refset_annotation_path, qq{$geno_repos/special_set/$strain/bcftools/special_set.annotation.vcf}, 
                              q{geno_refset_annotation_path bypassing lims object});

  is($fb->geno_refset_info_path, qq{$geno_repos/special_set/$strain/bcftools/special_set.info.json}, 
                              q{geno_refset_info_path bypassing lims object});

  is($fb->geno_refset_ploidy_path, qq{$geno_repos/special_set/$strain/bcftools/special_set.ploidy}, 
                              q{geno_refset_ploidy_path bypassing lims object});

  is($fb->geno_refset_genotype_base, qq{$geno_repos/special_set/$strain/genotypedb/special_set}, 
                              q{geno_refset_genotype_base bypassing lims object});

  is($fb->refs->[0], qq{$repos/references/$species/$strain/all/fasta/$strain.fa}, 
                              q{ref fasta path bypassing lims object});
}

{
  my $fb = Moose::Meta::Class->create_anon_class(
         roles => [qw/npg_tracking::data::geno_refset::find/])
         ->new_object({ repository        => $repos,
                        geno_refset_name  => 'Missing',
                        species           => $species,
                        strain            => $strain,
                      });

  is( $fb->geno_refset_path, undef, q{geno_refset_path is undefined});
  is( $fb->geno_refset_info_path, undef, q{geno_refset_info_path is undefined});
}

{
  local $ENV{NPG_CACHED_SAMPLESHEET_FILE} =
    't/data/samplesheet/samplesheet_7753.csv';
  # There is no geno_refset files for this run
  my %init = (id_run => 7753, position => 2, tag_index => 1);
  my $test =npg_tracking::data::geno_refset->new(repository => $repos, %init,
    lims => st::api::lims->new(%init));
  lives_and { is $test->geno_refset_path, undef } 'geno_refset_path is undefined';
  is($test->geno_refset_name, q[study2072], 'default geno_refset name is found');
}

1;
