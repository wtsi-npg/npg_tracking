use strict;
use warnings;
use Test::More tests => 13;
use Test::Exception;
use Moose::Meta::Class;
use File::Spec::Functions qw(catdir);
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use Cwd qw(cwd);
use File::Copy;
use File::Find;

my $current_dir = cwd();
my $repos = catdir($current_dir, q[t/data/repos1]);
my $gbs_repos = catdir($repos, q[gbs_plex]);

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

find({'wanted' => \&_copy_ref_rep, 'follow' => 0, 'no_chdir' => 1}, $gbs_repos);
$repos = $new;
$gbs_repos = catdir($repos, q[gbs_plex]);

{
  local $ENV{http_proxy} = 'wibble';
  use_ok('npg_tracking::data::gbs_plex::find');

  my $fb;
  lives_ok { $fb = Moose::Meta::Class->create_anon_class(
         roles => [qw/npg_tracking::data::gbs_plex::find/])
         ->new_object({ repository     => $repos,
                        gbs_plex_name  => 'Hs_W30467',                        
                      }) }
     'no error creating an object without id_run and position accessors';
  is($fb->gbs_plex_path, qq{$gbs_repos/Hs_W30467/default/all}, q{gbs_plex path bypassing lims object});
}

{
  my $fb = Moose::Meta::Class->create_anon_class(
         roles => [qw/npg_tracking::data::gbs_plex::find/])
         ->new_object({ repository     => $repos . q[/],
                        gbs_plex_name  => 'Hs_W30467',
                        aligner        => 'fasta',
                      });

  is($fb->gbs_plex_path, qq{$gbs_repos/Hs_W30467/default/all}, q{gbs_plex_path bypassing lims object});

  is($fb->gbs_plex_annotation_path, qq{$gbs_repos/Hs_W30467/default/all/bcftools/Hs_W30467.annotation.vcf}, 
                              q{gbs_plex_annotation_path bypassing lims object});

  is($fb->gbs_plex_info_path, qq{$gbs_repos/Hs_W30467/default/all/bcftools/Hs_W30467.info.json}, 
                              q{gbs_plex_info_path bypassing lims object});

  is($fb->gbs_plex_ploidy_path, qq{$gbs_repos/Hs_W30467/default/all/bcftools/Hs_W30467.ploidy}, 
                              q{gbs_plex_ploidy_path bypassing lims object});

  is($fb->refs->[0], qq{$gbs_repos/Hs_W30467/default/all/fasta/Hs_W30467.fa}, 
                              q{ref fasta path bypassing lims object});

}

{
  my $fb = Moose::Meta::Class->create_anon_class(
         roles => [qw/npg_tracking::data::gbs_plex::find/])
         ->new_object({ repository     => $repos,
                        gbs_plex_name  => 'Missing',
                      });

  is( $fb->gbs_plex_path, undef, q{gbs_plex_path is undefined});
  is( $fb->gbs_plex_info_path, undef, q{gbs_plex_info_path is undefined});
}



local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/repos1];
use_ok('npg_tracking::data::gbs_plex');

{ # There is no gbs plex name or files for this run
  my $test =npg_tracking::data::gbs_plex->new( repository => $repos, id_run => 7754, position => 1, tag_index => 2);
  lives_and { is $test->gbs_plex_path, undef } 'gbs_plex_path is undefined';
  is($test->gbs_plex_name, undef, 'gbs_plex_name is undefined');

}

1;


