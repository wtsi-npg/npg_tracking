package reference;

use strict;
use warnings;
use Test::More tests => 43;
use Test::Exception;
use File::Spec::Functions qw(catfile);
use Cwd qw(cwd);

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/repos];
my $repos = catfile(cwd, q[t/data/repos]);

use_ok('npg_tracking::data::reference::info');
use_ok('npg_tracking::data::reference::list');
use_ok('npg_tracking::data::reference::find');
use_ok('npg_tracking::data::reference');

{
  my $ruser = npg_tracking::data::reference->new(id_run => 1937, position => 1, repository => $repos);
  isa_ok($ruser, 'npg_tracking::data::reference');
  lives_ok {npg_tracking::data::reference->new(id_run => 1937, position => 1, tag_index => 4, repository => $repos)} 'can take tag index in the constructor';
}

{
  my $ruser = npg_tracking::data::reference->new(position => 8, id_run => 1937, repository => $repos, aligner => q[eland]);
  is( pop @{$ruser->refs}, catfile($repos, 'references/PhiX/default/all/eland/phix-illumina.fa'), 'phix reference for eland');
  is ($ruser->messages->count, 0, 'no messages');

  $ruser = npg_tracking::data::reference->new(position => 8, id_run => 1937, repository => $repos, aligner => q[bowtie]);
  is( pop @{$ruser->refs}, catfile($repos, 'references/PhiX/default/all/bowtie/phix-illumina.fa'), 'phix reference for bowtie');
  is ($ruser->messages->count, 0, 'no messages');

  $ruser = npg_tracking::data::reference->new(position => 8, id_run => 1937, repository => $repos, aligner => q[bwa]);
  is( pop @{$ruser->refs}, catfile($repos, 'references/PhiX/default/all/bwa/phix-illumina.fa'), 'phix reference for bwa explicitly');
  is ($ruser->messages->count, 0, 'no messages');

  $ruser = npg_tracking::data::reference->new(position => 8, id_run => 1937, 
                                                repository => $repos, aligner => q[bwa],
                                                species => q[Human],
                                               );
  is( $ruser->refs->[0], catfile($repos, q[references/Human/NCBI36/all/bwa/someref.fa]), 'human reference overwrite when species is set');

  $ruser = npg_tracking::data::reference->new(position => 8, id_run => 1937, 
                                                repository => $repos, aligner => q[bwa],
                                                reference_genome => q[Human (NCBI36)],
                                               );
  is ($ruser->species, q[Human], 'species is human');
  is ($ruser->strain, q[NCBI36], 'strain is NCBI36');
  is( $ruser->refs->[0], catfile($repos, q[references/Human/NCBI36/all/bwa/someref.fa]), 'human reference overwrite when reference_genome is set');
}

{
  my $ruser = npg_tracking::data::reference->new(position => 8, id_run => 1937, repository => $repos);
  is( pop @{$ruser->refs}, catfile(cwd, 't/data/repos/references/PhiX/default/all/bwa/phix-illumina.fa'), 'phix reference for lane 8');
  is( $ruser->messages->count, 0, 'no messages');


  $ruser = npg_tracking::data::reference->new(position => 4, id_run => 1937, repository => $repos);
  is( pop @{$ruser->refs}, catfile($repos, 'references/PhiX/default/all/bwa/phix-illumina.fa'), 'phix reference for lane 4');
  is( $ruser->messages->count, 0, 'no messages' );
}

{
  my $ruser = npg_tracking::data::reference->new(id_run => 4254, position => 1, tag_index => 1, 
                                                   repository => $repos);
  is ((scalar @{$ruser->refs()}), 0, 'number of ref returned for a component of a multiplex with tag 1');

  $ruser = npg_tracking::data::reference->new(id_run => 4254, position => 1, tag_index => 13, repository => $repos);
  throws_ok {$ruser->refs()} qr/No tag with index 13 in lane 1 batch 5347/, 'error when using a non-existing tag index';

  $ruser = npg_tracking::data::reference->new(id_run => 4254, position => 4, tag_index => 1, repository => $repos);
  throws_ok {$ruser->refs()} qr/No plexes defined for lane 4 in batch 5347/, 'error when using a tag index with a non-pool lane';
}

{
  my $ruser = npg_tracking::data::reference->new(id_run => 5175, position => 1, tag_index => 1, repository => $repos, aligner => 'fasta');
  my $refpath =  catfile($repos, 'references/Bordetella_bronchiseptica/RB50/all/fasta/ref.fa');

  is (pop @{$ruser->refs()}, $refpath, 'ref_genome ref');

  my $ref_info =  $ruser->ref_info;
  isa_ok($ref_info, 'npg_tracking::data::reference::info');
  is ($ref_info->ref_path, $refpath, 'refpath field');
  is ($ref_info->aligner, q[fasta], 'aligner field');
  is ($ref_info->aligner_options, q[npg_default], 'aligner options not available');
}

{
  my $ruser = npg_tracking::data::reference->new(id_run => 4254, position => 1, repository => $repos);
  my $refpath = catfile($repos, 'references/Streptococcus_pneumoniae/ATCC_700669/all/bwa/S_pneumoniae_700669.fasta');
  is ((scalar @{$ruser->refs()}), 0, 'number of ref returned for a multiplex sample');
}

{
  my $ruser = npg_tracking::data::reference->new(id_run => 5175, position => 1, tag_index => 1, repository => $repos, aligner => 'bwa');
  my $refpath =  catfile($repos, 'references/Bordetella_bronchiseptica/RB50/all/bwa/ref.fa');

  is (pop @{$ruser->refs()}, $refpath, 'ref_genome ref');

  my $ref_info =  $ruser->ref_info;
  isa_ok($ref_info, 'npg_tracking::data::reference::info');
  is ($ref_info->ref_path, $refpath, 'refpath field');
  is ($ref_info->aligner, q[bwa], 'aligner field');
  is ($ref_info->aligner_options, q{}, 'empty aligner options, use bwa default');
}

{

  my $phix = join q[/], $repos, q[references/PhiX/default/all/bwa/phix-illumina.fa];

  my $ruser = npg_tracking::data::reference->new(
                         repository => $repos,
                         id_run => 4254,
                         position => 8,
                      );
  is( @{$ruser->refs}, 0, 'no refs for a pool lane');

  $ruser = npg_tracking::data::reference->new(
                         repository => $repos,
                         id_run => 6993,
                         position => 8,
                         for_spike => 1
                      );
  my $refs = $ruser->refs;
  is(scalar @{$refs}, 1, '1 ref for spiked phix returned');
  is($refs->[0], $phix, 'phix ref for a pool lane with for_spike flag set');

  $ruser = npg_tracking::data::reference->new(
                         repository => $repos,
                         id_run => 6993,
                         position => 8,
                         tag_index => 168,
                      );
  is($ruser->refs->[0], $phix, 'phix ref for a tag for a spike');

  $ruser = npg_tracking::data::reference->new(
                         repository => $repos,
                         id_run => 4140,

                         position => 8,
                      );
  is( @{$ruser->refs}, 0, 'no refs for a lane');

  $ruser = npg_tracking::data::reference->new(
                         repository => $repos,
                         id_run => 4140,
                         position => 8,
                         for_spike => 1
                      );
  is($ruser->refs->[0], $phix, 'phix ref for a lane with for_spike flag set');
}

{
  no warnings 'once';
  my $no_align = $npg_tracking::data::reference::list::NO_ALIGNMENT_OPTION;
  my $ruser = npg_tracking::data::reference->new(
                         repository => $repos,
                         reference_genome => $no_align,
                         id_run => 4140,
                         position => 4,
                      );
  is(scalar @{$ruser->refs}, 0, 'no reference found for no-align option');
  is($ruser->messages->count, 1, 'one message saved');
  is($ruser->messages->pop, $no_align, 'correct message saved');
}


1;
