#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       29 July 2009
# Last Modified: $Date: 2013-01-23 16:49:39 +0000 (Wed, 23 Jan 2013) $
# Id:            $Id: 10-reference-find.t 16549 2013-01-23 16:49:39Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-reference-find.t $
#

package reference;

use strict;
use warnings;
use Test::More tests => 42;
use Test::Exception;
use File::Spec::Functions qw(catfile);
use Cwd qw(cwd);
use Moose::Meta::Class;

my $central = catfile(cwd, q[t/data/repos]);
my $repos = catfile(cwd, q[t/data/repos/references]);
my $bwa_human_ref = q[Human/NCBI36/all/bwa/someref.fa];

use_ok('npg_tracking::data::reference::find');

{
  my $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central,
                          strain => q[some-strain],
                       });
  throws_ok { $ruser->_get_reference_path() } qr/Organism\ should\ be\ defined/, 
           'croak on organism not defined';
  throws_ok { $ruser->_get_reference_path(q[PhiX]) } qr/Binary bwa reference for PhiX, some-strain, all does not exist/, 'error message when strain is not available';

  $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central,
                         aligner => q[some],
                       });
  throws_ok { $ruser->_get_reference_path(q[PhiX]) } qr/Binary some reference for PhiX, default, all does not exist/, 'error message when aligner does not exist';
  throws_ok { $ruser->_get_reference_path(q[PhiX], q[my_strain]) } qr/Binary some reference for PhiX, my_strain, all does not exist/, 'error message when aligner does not exist';

  $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central,
                         subset => q[chr3]
                       });
  throws_ok { $ruser->_get_reference_path(q[PhiX]) } qr/Binary bwa reference for PhiX, default, chr3 does not exist/, 'error message for non-existing subset';
  throws_ok { $ruser->_get_reference_path(q[human]) } qr/Binary\ bwa\ reference/, 'error message when the directory structure for the binary ref is missing';

  $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central,});
  is ($ruser->_get_reference_path(q[Human]), catfile($repos, q[Human/default/all/bwa/someref.fa]), 
           'correct reference path'); 
  throws_ok { $ruser->_get_reference_path(q[Human], q[no_ref_strain]) } qr/Reference file with .fa or .fasta or .fna extension not found in/, 'error message when no genome ref is found in the fasta directory';
  is ($ruser->_get_reference_path(q[Human], q[fna_strain]), catfile($repos, q[Human/fna_strain/all/bwa/someref.fna]), 'genome reference with .fna extension is found');

  $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central, aligner => 'fasta'});
  is ($ruser->_get_reference_path(q[Human], q[fna_strain]), catfile($repos, q[Human/fna_strain/all/fasta/someref.fna]), 'genome reference with .fna extension is found');
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
  my $no_align = $npg_tracking::data::reference::list::NO_ALIGNMENT_OPTION;

  my $ruser = Moose::Meta::Class->create_anon_class(
          roles => [qw/npg_tracking::data::reference::find/])
          ->new_object({ repository => $central });
  is($ruser-> _preset_ref2ref_path($no_align), q[], 'no preset ref for no-align option');
  is($ruser->messages->pop, 'Incorrect reference genome format Not suitable for alignment', 'correct message saved');
}