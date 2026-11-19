package sample_retriever_test;
use Moose;
with 'npg_tracking::ultimagen::sample_retriever';

package main_test;
use strict;
use warnings;
use Test::More tests => 33;
use Test::Exception;

use_ok('sample_retriever_test');

my $rf = 't/data/ultimagen/425347-20250821_1214';

throws_ok { sample_retriever_test->new()->get_samples() }
  qr/Either runfolder_path or manifest_path should be set/,
  'error if no attributes are set';

my $samples_rli = sample_retriever_test->new(runfolder_path => $rf);
my $samples_li = $samples_rli->get_samples();
is (scalar @{$samples_li}, 8, 'returned eight samples');
is ($samples_rli->library_pool, '18Aug25 D7_CooperSteer_5priem plus guide',
  'library pool name is correct');
is ($samples_rli->input_file_path, "${rf}/425347_LibraryInfo.xml",
  'input file path is correct');

my $samples_rma = sample_retriever_test->new(
  runfolder_path => $rf,
  manifest_path => "${rf}/425347_LibraryInfo.xml",
);
throws_ok { $samples_rma->library_pool }
  qr/Input file name 425347_LibraryInfo.xml does not have the CSV extension/,
  'error if the manifest file does not have correct extension';

$samples_rma = sample_retriever_test->new(
  runfolder_path => $rf,
  manifest_path => "${rf}/manifest.csv"
);
my $samples_ma = $samples_rma->get_samples();
is (scalar @{$samples_ma}, 8, 'returned eight samples');
is ($samples_rma->library_pool, 'manifest', 'library pool name is correct');
is ($samples_rma->input_file_path, "${rf}/manifest.csv",
  'input file path is correct');

for my $sample (($samples_li->[0], $samples_ma->[0])) {
  is ($sample->id(), 'iNeuron15923026', 'correct sample id');
  is ($sample->library_name(), '1_GEX_iA_iN_SCREEN', 'correct library name');
  is ($sample->index_label(), 'Z0001', 'correct index label');
  is ($sample->index_sequence(), 'CAGCTCGAATGCGAT', 'correct index sequence');
  is ($sample->tag_index, 1, 'correct NPG tag index');
}
is ($samples_li->[0]->application_type(), 'scRNA_GEX_10x_5prime_v3',
  'correct application type');
is ($samples_ma->[0]->application_type(), undef, 'undefined application type');

for my $sample (($samples_li->[7], $samples_ma->[7])) {
  is ($sample->id(), 'iNeuron15923033', 'correct sample id');
  is ($sample->library_name(), '4_dgRNA_iA_iN_SCREEN', 'correct library name');
  is ($sample->index_label(), 'Z0008', 'correct index label');
  is ($sample->index_sequence(), 'CACATCCTGCATGTGAT', 'correct index sequence');
  is ($sample->tag_index, 8, 'correct NPG tag index');
}
is ($samples_li->[7]->application_type(), 'native',
  'correct application type');
is ($samples_ma->[7]->application_type(), undef, 'undefined application type');

1;
