package reference;

use strict;
use warnings;
use Test::More tests => 49;
use Test::Exception;
use File::Spec::Functions qw(catfile);
use Cwd qw(cwd);
use Moose::Meta::Class;
use Test::MockObject;
use File::Find;
use File::Spec qw(splitpath);
use File::Path qw(make_path);
use File::Copy;
use File::Temp qw(tempdir);

my $current_dir = cwd();
my $central = catfile($current_dir, q[t/data/repos]);
my $repos = catfile($current_dir, q[t/data/repos/references]);
my $transcriptome_repos = catfile($current_dir, q[t/data/repos1]);
my $bwa_human_ref = q[Human/NCBI36/all/bwa/someref.fa];

my $new = tempdir(UNLINK => 1);

sub _copy_ref_rep {
  my $n = $File::Find::name;
  if (-d $n || -l $n) {
    return;
  }
  my ($volume,$directories,$file_name) = File::Spec->splitpath($n);
  $directories =~ s/$central//smx;
  $directories = $new . $directories;
  make_path $directories;
  copy $n, $directories;
}

find({'wanted' => \&_copy_ref_rep, 'follow' => 0, 'no_chdir' => 1}, $central);
$central = $new;
$repos = "$central/references";
chdir "$repos/Streptococcus_pneumoniae";
symlink 'ATCC_700669', 'default';
chdir '../Human';
symlink 'NCBI36', 'default';
chdir $current_dir;

use_ok('npg_tracking::data::reference::find');

{
  my $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central,
                          strain => q[some-strain],
                       });
  throws_ok { $ruser->_get_reference_path() } qr/Organism\ should\ be\ defined/, 
           'croak on organism not defined';
  throws_ok { $ruser->_get_reference_path(q[PhiX]) } 
    qr/Binary bwa reference for PhiX, some-strain, all does not exist/, 'error message when strain is not available';

  $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central,
                         aligner => q[some],
                       });
  throws_ok { $ruser->_get_reference_path(q[PhiX]) } 
    qr/Binary some reference for PhiX, default, all does not exist/, 'error message when aligner does not exist';
  throws_ok { $ruser->_get_reference_path(q[PhiX], q[my_strain]) } 
    qr/Binary some reference for PhiX, my_strain, all does not exist/, 'error message when aligner does not exist';

  $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central,
                         subset => q[chr3]
                       });
  throws_ok { $ruser->_get_reference_path(q[PhiX]) } 
    qr/Binary bwa reference for PhiX, default, chr3 does not exist/, 'error message for non-existing subset';
  throws_ok { $ruser->_get_reference_path(q[human]) } 
    qr/Binary\ bwa\ reference/, 'error message when the directory structure for the binary ref is missing';

  $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central,});
  is ($ruser->_get_reference_path(q[Human]), catfile($repos, q[Human/default/all/bwa/someref.fa]), 
           'correct reference path'); 
  throws_ok { $ruser->_get_reference_path(q[Human], q[no_ref_strain]) } 
    qr/Reference file with .fa or .fasta or .fna extension not found in/, 'error message when no genome ref is found in the fasta directory';
  is ($ruser->_get_reference_path(q[Human], q[fna_strain]), catfile($repos, q[Human/fna_strain/all/bwa/someref.fna]), 
    'genome reference with .fna extension is found');

  $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central, aligner => 'fasta'});
  is ($ruser->_get_reference_path(q[Human], q[fna_strain]), catfile($repos, q[Human/fna_strain/all/fasta/someref.fna]),
    'genome reference with .fna extension is found');
}

{
  my $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central, });
  throws_ok { $ruser->_preset_ref2ref_path() } qr/Reference genome is not defined or empty/, 'missing or empty attribute  error';
  throws_ok { $ruser->_preset_ref2ref_path(q[]) } qr/Reference genome is not defined or empty/, 'missing or empty attribute  error';

  is ($ruser->_preset_ref2ref_path(q[Tiger]), q[], 'incorrect ref genome - return empty string');
  like ($ruser->messages->pop, qr/Incorrect reference genome format Tiger/, 'incorrect ref genome format error logged');

  is ($ruser->_preset_ref2ref_path(q[Tiger ()]), q[], 'incorrect ref genome - return empty string');
  like ($ruser->messages->pop, qr/Incorrect reference genome format Tiger ()/, 'incorrect ref genome format error logged');

  is ($ruser->_preset_ref2ref_path(q[ (tiger)]), q[], 'incorrect ref genome - return empty string');
  like ($ruser->messages->pop, qr/Incorrect reference genome format/, 'incorrect ref genome format error logged');

  is ($ruser->_preset_ref2ref_path(q[ ]), q[], 'incorrect ref genome - return empty string');
  like ($ruser->messages->pop, qr/Incorrect reference genome format  /, 'incorrect ref genome format error logged');

  throws_ok {$ruser->_preset_ref2ref_path(q[Human (dada) ])} qr/Binary bwa reference for Human, dada, all does not exist/, 'non-existing strain error';
  throws_ok {$ruser->_preset_ref2ref_path(q[dodo (fna_strain) ])} qr/Binary bwa reference for dodo, fna_strain, all does not exist/, 'non-existing organism error';
}

{
  my $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central, });

  is($ruser->strain, q[default], 'default strain');
  is($ruser->reference_genome, undef, 'reference_genome not defined by default');
}

{
  my $species = q[Human];
  my $strain = q[NCBI36];
  my $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central, species => $species, strain => $strain});

  is($ruser->strain, $strain, qq[strain $strain]);
  is($ruser->species, $species, qq[species $species]);
  is($ruser->reference_genome, undef, 'reference_genome not defined by default');
  is($ruser->refs->[0], catfile($repos, $bwa_human_ref), 'path to human reference');
}

{
  my $species = q[Human];
  my $strain = q[NCBI36];
  my $reference_genome = $species . q[ (] . $strain .q[)];
  my $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central, reference_genome => $reference_genome});

  is($ruser->strain, $strain, qq[strain $strain]);
  is($ruser->species, $species, qq[species $species]);
  is($ruser->reference_genome, $reference_genome, qq[reference_genome $reference_genome]);
  is($ruser->refs->[0], catfile($repos, $bwa_human_ref), 'path to human reference');
}

{
  my $species = q[Human];
  my $strain = q[NCBI36];
  my $reference_genome = q[dodo];
  my $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central, 
                         species => $species, 
                         strain => $strain, 
                         reference_genome => $reference_genome});

  is($ruser->strain, $strain, qq[strain $strain]);
  is($ruser->species, $species, qq[species $species]);
  is($ruser->reference_genome, $reference_genome, qq[reference_genome $reference_genome]);
  is($ruser->refs->[0], catfile($repos, $bwa_human_ref), 'path to human reference');
}

{
  my $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central });
  
  is(join(q[ ], $ruser->_parse_reference_genome(q[Salmonella_enterica (Enteritidis_P125109)])), q[Salmonella_enterica Enteritidis_P125109], 'ref genome parsing');
  is(join(q[ ], $ruser->_parse_reference_genome(q[Homo_sapiens (CGP_GRCh37.NCBI.allchr_MT)])), q[Homo_sapiens CGP_GRCh37.NCBI.allchr_MT], 'ref genome parsing');
  is($ruser->_parse_reference_genome(q[Salmonella_enterica]), undef, 'ref genome parsing');
}

{
  require npg_tracking::data::reference::list;
  no warnings 'once';
  my $no_align = $npg_tracking::data::reference::list::NO_ALIGNMENT_OPTION;

  my $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central });
  is($ruser-> _preset_ref2ref_path($no_align), q[], 'no preset ref for no-align option');
  is($ruser->messages->pop, qq[Incorrect reference genome format $no_align], 'correct message saved');

  $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central});
  my $lims = Test::MockObject->new();
  $lims->mock( 'reference_genome', sub { $no_align } );
  is($ruser->lims2ref($lims), q[], qq[no reference returned for '$no_align' option]);
  is($ruser->messages->pop, $no_align, 'correct message saved');
}

{
  my $ruser = Moose::Meta::Class->create_anon_class(
      roles => [qw/npg_tracking::data::transcriptome::find/])
      ->new_object({ repository => $transcriptome_repos });
  is(join(q[ ],$ruser->_parse_reference_genome(q[Homo_sapiens (1000Genomes_hs37d5 + ensembl_74_transcriptome)])),'Homo_sapiens 1000Genomes_hs37d5 ensembl_74_transcriptome','transcriptome ref genome parsing ok with correct format'); 
  is(join(q[ ],$ruser->_parse_reference_genome(q[Homo_sapiens (1000Genomes_hs37d5 ; ensembl_74_transcriptome)])),q[],'transcriptome ref genome parsing ok - returns empty with incorrect delimiter'); 
  is(join(q[ ],$ruser->_parse_reference_genome(q[Homo_sapiens (1000Genomes_hs37d5 ensembl_74_transcriptome)])),q[],'transcriptome ref genome parsing ok - returns empty with missing delimiter'); 
  is(join(q[ ],$ruser->_parse_reference_genome(q[Homo_sapiens (1000Genomes_hs37d5 + ensembl_74_transcriptome])),q[],'transcriptome ref genome parsing ok - returns empty with missing bracket'); 

  $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ 'repository' => $transcriptome_repos, 'aligner' => 'fasta' });
  my $lims = Test::MockObject->new();
  $lims->mock( 'reference_genome', sub { q[Homo_sapiens (1000Genomes_hs37d5 + ensembl_74_transcriptome)] } );
  is ($ruser->lims2ref($lims), catfile($transcriptome_repos, q[references/Homo_sapiens/1000Genomes_hs37d5/all/fasta/hs37d5.fa]), 'find fasta genome reference even when transcriptome also given in key');
}

1;
