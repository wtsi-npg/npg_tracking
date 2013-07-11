use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;
use File::Temp qw/ tempdir /;

BEGIN {
  use_ok( q{npg_tracking::illumina::run::lims::samplesheet} );
}
my $module = q{npg_tracking::illumina::run::lims::samplesheet};

my $tdir = tempdir( CLEANUP => 1 );

{
  my $ss = $module->new(path => 't/data/samplesheet/MS2026264-300V2.csv');
  isa_ok ($ss, $module);
  my $data;
  lives_ok {$data = $ss->data} 'MiSeq samplesheet parsed without error';

#  use Data::Dumper;
#  diag Dumper $data;
}

{
  my $data;
  lives_ok {$data = $module->new(path => 't/data/samplesheet/MS2026264-300V2.csv')->data}
    'got data from the samplesheet OK';
  my $target;
  lives_ok {$target = $module->new(path => join(q[/], $tdir, 'miseq1.csv'), data => $data) }
    'created object with data OK';
  lives_ok { $target->generate() } 'MiSeq samplesheet generated from given data';
  ok(-e $target->path, 'target file exists');
}


1;
