package reference;

use strict;
use warnings;
use Test::More tests => 20;
use Test::Exception;
use File::Spec::Functions qw(catfile);
use Cwd qw(cwd);
use Moose::Meta::Class;
use File::Temp qw/ tempdir /;
use File::Find;
use File::Spec qw/ splitpath /;
use File::Path qw/make_path/;
use File::Copy;

my $current_dir = cwd();
my $current = $current_dir . '/t/data/repos2/references2';
my $root = tempdir(UNLINK => 1);
my $new = $root . '/references';
sub _copy_ref_rep {
  my $n = $File::Find::name;
  if (-d $n || -l $n) {
    return;
  }
  my ($volume,$directories,$file_name) = File::Spec->splitpath($n);
  $directories =~ s/$current//smx;
  $directories = $new . $directories;
  make_path $directories;
  copy $n, $directories;
}
find({'wanted' => \&_copy_ref_rep, 'follow' => 0, 'no_chdir' => 1}, $current);

make_path "$new/taxon_ids";

symlink "$new/Homo_sapiens/NCBI36", "$new/Homo_sapiens/default";
symlink "$new/Human_herpesvirus_4/EB1", "$new/Human_herpesvirus_4/default";
symlink "$new/NPD_Chimera/010302", "$new/NPD_Chimera/default";
symlink "$new/PhiX/Sanger", "$new/PhiX/default";


chdir $new;
symlink "Homo_sapiens", "Human";
symlink "Human_herpesvirus_4", "Epstein-Barr_virus";
symlink "Homo_sapiens", "Other";
chdir 'taxon_ids';
symlink "../Homo_sapiens", "1002";
symlink "../Homo_sapiens/NCBI36", "1003";
symlink "../PhiX", "1007";
chdir $current_dir;
use_ok('npg_tracking::data::reference::list');

{
  throws_ok { Moose::Meta::Class->create_anon_class(
         roles => [qw/npg_tracking::data::reference::list/])
         ->new_object({ ref_repository => q[non-existing],}) }
     qr/Validation failed/, 'error message for non-existing repository';
}

my $REP_ROOT=$npg_tracking::data::reference::list::REP_ROOT;

SKIP: {
  skip 'No live reference repository', 5 unless -e $REP_ROOT;
    
  my $live_lister =  Moose::Meta::Class->create_anon_class(
         roles => [qw/npg_tracking::data::reference::list/])->new_object();
  is ($live_lister->ref_repository, join(q[/], $REP_ROOT . q[references]), 'live reference repository location');
  is ($live_lister->adapter_repository, join(q[/], $REP_ROOT .q[adapters]), 'live adapter repository location');
  is ($live_lister->genotypes_repository, join(q[/], $REP_ROOT . q[genotypes]), 'live genotypes repository location');
  is ($live_lister->tag_sets_repository, join(q[/], $REP_ROOT .q[tag_sets]), 'live tag sets repository location');
SKIP: {
   skip 'transcriptomes not yet copied to  $REP_ROOT from /nfs/srpipe_references', 1 unless -d join(q[/], $REP_ROOT .q[transcriptomes]) ;

  is ($live_lister->transcriptome_repository, join(q[/], $REP_ROOT .q[transcriptomes]), 'live transcriptomes repository location');
  }
};

{
  my $repos = $new;
  my $lister = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::list/])
          ->new_object(repository=>$root);
  lives_ok { $lister->repository_contents} 'repository listing lives';
  my $full_report;
  lives_ok { $full_report = $lister->report } 'reporting lives';
  my $short_report;
  lives_ok { $short_report = $lister->short_report } 'short reporting lives';

  my @expexted_full = ('Species:Strain,Is Default?,Taxon Ids,Synonyms',
                       'Homo_sapiens:GRCh37_53,0,,',
                       'Homo_sapiens:NCBI36,1,1002;1003,Human;Other',
                       'Human_herpesvirus_4:EB1,1,,Epstein-Barr_virus',
                       'NPD_Chimera:010203,0,,',
                       'NPD_Chimera:010302,1,,',
                       'PhiX:Illumina,0,,',
                       'PhiX:Sanger,1,1007,'
                      );
  is ($full_report, join("\n", @expexted_full) . "\n", 'full report as expected');
  
  my @expected_short = ('Homo_sapiens (GRCh37_53)',
                        'Homo_sapiens (NCBI36)',
                        'Human_herpesvirus_4 (EB1)',
                        'NPD_Chimera (010203)',
                        'NPD_Chimera (010302)',
                        'PhiX (Illumina)',
                        'PhiX (Sanger)',
                        $npg_tracking::data::reference::list::NO_ALIGNMENT_OPTION,
                       );
  is ($short_report, join("\n", @expected_short) . "\n", 'short report as expected');
}

{
  my $repos = $new;
  my $lister = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::list/])
          ->new_object(all_species => 0, repository=>$root,);
  lives_ok { $lister->repository_contents} 'repository listing lives';

  my @expexted_full = ('Species:Strain,Is Default?,Taxon Ids,Synonyms',
                       'Homo_sapiens:GRCh37_53,0,,',
                       'Homo_sapiens:NCBI36,1,1002;1003,Human;Other',
                       'Human_herpesvirus_4:EB1,1,,Epstein-Barr_virus',
                       'PhiX:Illumina,0,,',
                       'PhiX:Sanger,1,1007,'
                      );
  is ($lister->report, join("\n", @expexted_full) . "\n", 'full report as expected');
  
  my @expected_short = ('Homo_sapiens (GRCh37_53)',
                        'Homo_sapiens (NCBI36)',
                        'Human_herpesvirus_4 (EB1)',
                        'PhiX (Illumina)',
                        'PhiX (Sanger)',
                        $npg_tracking::data::reference::list::NO_ALIGNMENT_OPTION,
                       );
  is ($lister->short_report, join("\n", @expected_short) . "\n", 'short report as expected');
 
  my $file =  catfile(tempdir( CLEANUP => 1 ), q[test]);
  lives_ok {$lister->report($file)} 'report with writing to file lives';
  ok((-e $file), 'file created');
}

{
  unlink "$new/Human_herpesvirus_4/default";
  my $lister = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::list/])
          ->new_object(repository => $root,);
  throws_ok { $lister->repository_contents} qr/No default strain link for Human_herpesvirus_4/,
    'repository listing error for no default';
}

{
  my $lister = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::list/])->new_object(repository=>q[t/data/repos1],);
  is ($lister->bait_report, "Bait Name\tReferences\nHuman_all_exon_50MB\t1000Genomes_hs37d5\n", 'bait report by bait name');
  is ($lister->bait_report_by_reference, "Reference\tBait Names\n1000Genomes_hs37d5\tHuman_all_exon_50MB\n", 'bait report by reference name');
}

1;
