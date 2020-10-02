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

my $current_dir = cwd();
my $repos = catdir($current_dir, q[t/data/repos1]);
my $pp_repos = catdir($repos, q[primer_panel]);
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

find({'wanted' => \&_copy_ref_rep, 'follow' => 0, 'no_chdir' => 1}, $pp_repos);
find({'wanted' => \&_copy_ref_rep, 'follow' => 0, 'no_chdir' => 1}, $ref_repos);
$repos = $new;
$pp_repos = catdir($repos, q[primer_panel]);


{
  local $ENV{http_proxy} = 'wibble';
  use_ok('npg_tracking::data::primer_panel::find');

  my $fb;
  lives_ok { $fb = Moose::Meta::Class->create_anon_class(
         roles => [qw/npg_tracking::data::primer_panel::find/])
         ->new_object({ repository        => $repos,
                        primer_panel_name => 'nCoV-2019',
                        species           => 'SARS-CoV-2',
                        strain            => 'MN908947.3',                       
                      }) }
  'no error creating an object without id_run and position accessors';

}

{
  use_ok('npg_tracking::data::primer_panel');
  local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} = q[t/data/samplesheet/samplesheet_33990.csv];
  my $fb = npg_tracking::data::primer_panel->new ( repository => $repos, 
                                                   id_run => 33990,
                                                   position => 1,
                                                   tag_index => 1);
  
  is($fb->primer_panel_path, qq{$pp_repos/nCoV-2019/default/SARS-CoV-2/MN908947.3},
     q{primer_path correct via lims - default version});

  is($fb->primer_panel_bed_file, qq{$pp_repos/nCoV-2019/default/SARS-CoV-2/MN908947.3/nCoV-2019.bed}, 
     q{primer_panel_bed_file correct via lims});

  my $fc = npg_tracking::data::primer_panel->new ( repository => $repos, 
                                                   id_run => 33990,
                                                   position => 1,
                                                   tag_index => 2);
  
  is($fc->primer_panel_path, qq{$pp_repos/nCoV-2019/V2/SARS-CoV-2/MN908947.3},
     q{primer_path correct via lims - version specified});

  is($fc->primer_panel_bed_file, qq{$pp_repos/nCoV-2019/V2/SARS-CoV-2/MN908947.3/nCoV-2019.bed}, 
     q{primer_panel_bed_file correct via lims});

  my $fd = npg_tracking::data::primer_panel->new ( repository => $repos,
                                                   id_run => 33990,
                                                   position => 1,
                                                   tag_index => 3);

  is($fd->primer_panel_path, qq{$pp_repos/nCoV-2019/V3/SARS-CoV-2/MN908947.3},
     q{primer_path correct via lims - version and revision specified});

  is($fd->primer_panel_bed_file, qq{$pp_repos/nCoV-2019/V3/SARS-CoV-2/MN908947.3/nCoV-2019.bed},
     q{primer_panel_bed_file correct via lims});

}

{
  use_ok('npg_tracking::data::primer_panel');
  local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} = q[t/data/samplesheet/samplesheet_27483.csv];
  my $test = npg_tracking::data::primer_panel->new ( repository => $repos,
                                                     id_run => 27483,
                                                     position => 1,
                                                     tag_index => 1);
  lives_and { is $test->primer_panel_path, undef } 'primer_panel_path is undefined - 27483_1';
  is($test->primer_panel_name, undef, 'primer_panel_name is undefined - 27483_1');
}

{
  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/repos1];
  my $test =npg_tracking::data::primer_panel->new( repository => $repos,
                                                   id_run => 7754,
                                                   position => 1,
                                                   tag_index => 2);
  lives_and { is $test->primer_panel_path, undef } 'primer_panel_path is undefined - 7754_1';
  is($test->primer_panel_name, undef, 'primer_panel_name is undefined - 7754_1');

}

1;
