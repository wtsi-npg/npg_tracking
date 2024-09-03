use strict;
use warnings;
use Test::More tests => 14;
use Test::Exception;

my @imports = qw/parse_reference_genome_name/;
use_ok('npg_tracking::data::reference::util', @imports);
can_ok('npg_tracking::data::reference::util', @imports);

throws_ok { parse_reference_genome_name() }
  qr//, 'error if the input is undefined';
throws_ok { parse_reference_genome_name(q[]) } qr//,
  'error if the input is an empty string';

my @ref = parse_reference_genome_name(q[Salmonella_enterica (Enteritidis_P125109)]);
is_deeply (\@ref, [qw(Salmonella_enterica Enteritidis_P125109)],
  'species and strain are returned');

@ref = parse_reference_genome_name(
  q[Homo_sapiens (1000Genomes_hs37d5 + ensembl_74_transcriptome)]
);
is_deeply (\@ref, ['Homo_sapiens', '1000Genomes_hs37d5',
  'ensembl_74_transcriptome', undef],
  'transcriptome ref genome parsing ok with correct format');
@ref = parse_reference_genome_name(
  q{Homo_sapiens (1000Genomes_hs37d5 + ensembl_74_transcriptome) [star}
);
is_deeply (\@ref, ['Homo_sapiens', '1000Genomes_hs37d5',
  'ensembl_74_transcriptome', undef],
  'aligner ignored due to a missing square bracket');

is (join(q[|], parse_reference_genome_name(
    q[Homo_sapiens (1000Genomes_hs37d5 + ensembl_74_transcriptome) [star]])
  ),'Homo_sapiens|1000Genomes_hs37d5|ensembl_74_transcriptome|star',
  'transcriptome ref genome parsing ok with aligner');
@ref = parse_reference_genome_name(q[Homo_sapiens (1000Genomes_hs37d5) [star]]);
is_deeply (\@ref, ['Homo_sapiens', '1000Genomes_hs37d5', undef, 'star'],
  'transcriptome ref genome parsing ok with aligner and no transcriptome');

lives_ok {
  parse_reference_genome_name(q[Salmonella_enterica Enteritidis_P125109])
} 'incorrect string pattern does not cause an error';
is (parse_reference_genome_name(q[Salmonella_enterica Enteritidis_P125109]),
  undef, 'no brackets - wrong pattern, undefined value is returned');
is (parse_reference_genome_name(q[Homo_sapiens (1000Genomes_hs37d5 + )]), undef,
 'missing transcriptome version - wrong pattern');
is (parse_reference_genome_name(
    q[Homo_sapiens (1000Genomes_hs37d5 ensembl_74_transcriptome)]
  ), undef, 'missing transcriptome delimiter - wrong pattern');
is (parse_reference_genome_name(
  q[Homo_sapiens (1000Genomes_hs37d5 + ensembl_74_transcriptome]), undef,
  'missing bracket - wrong pattern');

1;
