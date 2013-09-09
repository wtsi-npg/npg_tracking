use strict;
use warnings;
use Test::More tests => 11;
use Test::Exception;
use File::Temp qw/ tempdir /;

BEGIN {
  use_ok( q{npg_tracking::illumina::run::lims::samplesheet} );
}
my $module = q{npg_tracking::illumina::run::lims::samplesheet};
my $path = 't/data/samplesheet/miseq_default.csv';

my $tdir = tempdir( CLEANUP => 1 );

{
  my $ss = $module->new(path => $path);
  isa_ok ($ss, $module);
  my $data;
  lives_ok {$data = $ss->data} 'MiSeq samplesheet parsed without error';
}

{
  my $data;
  lives_ok {$data = $module->new(path => $path)->data}
    'got data from the samplesheet OK';
  my $target;
  lives_ok {$target = $module->new(path => join(q[/], $tdir, 'miseq1.csv'), data => $data) }
    'created object with data OK';
  lives_ok { $target->generate() } 'MiSeq samplesheet generated from given data';
  ok(-e $target->path, 'target file exists');
}

{
  my $ss =  $module->new(id_run => 10262,  path => $path);
  is ($ss->is_pool, 0, 'is_pool false on run level');
  is ($ss->is_control, 0, 'is_control false on run level');
  is ($ss->library_id, undef, 'library_id undef on run level');
  is ($ss->library_name, undef, 'library_name undef on run level');
}


1;
