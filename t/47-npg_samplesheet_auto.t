use strict;
use warnings;
use Test::More tests => 14;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Moose::Meta::Class;
use Log::Log4perl qw(:easy);
use File::chdir;

use_ok('npg::samplesheet::auto');

my $util = Moose::Meta::Class->create_anon_class(
             roles => [qw/npg_testing::db/])->new_object({});
my $schema_wh = $util->create_test_db(q[WTSI::DNAP::Warehouse::Schema],
                                      q[t/data/fixtures_lims_wh]);
my $schema = $util->create_test_db(q[npg_tracking::Schema],
                                   q[t/data/dbic_fixtures]);

{
  my $sm;
  lives_ok { $sm = npg::samplesheet::auto->new(
    npg_tracking_schema => $schema,
    mlwh_schema         => $schema_wh) } 'MiSeq monitor object';
  isa_ok($sm, 'npg::samplesheet::auto');
  is ($sm->instrument_format, 'MiSeq', 'default instrument format is MiSeq');

  throws_ok { npg::samplesheet::auto->new(
    npg_tracking_schema => $schema,
    mlwh_schema         => $schema_wh,
    instrument_format   => 'NovaSeq'
  )}
  qr/Samplesheet auto-generator is not implemented for NovaSeq instrument format/,
  'Error for an invalid instrument format';
}

{
  is(npg::samplesheet::auto::_id_run_from_samplesheet(
      't/data/samplesheet/miseq_default.csv'), 10262,
      'id run retrieved from a samplesheet');
  lives_and { is npg::samplesheet::auto::_id_run_from_samplesheet('some_file'), undef}
      'undef returned for a non-exisitng samplesheet';
}

{
  my $dir = tempdir(UNLINK => 1);

  my $sm = npg::samplesheet::auto->new(
    npg_tracking_schema => $schema,
    mlwh_schema         => $schema_wh
  );

  my $file = join q[/], $dir, 'myfile';
  `touch $file`;
  lives_ok {
    $sm->_move_samplesheet_if_needed($file . '_some');
  } 'OK to call with a file path that does not exist';
  $sm->_move_samplesheet_if_needed($file);
  ok(!-e $file, 'original file does not exist');
  ok(-e $file.'_invalid', 'file has been moved');

  my $sdir = join q[/],  $dir, 'samplesheet';
  mkdir $sdir;
  mkdir $sdir . '_old';
  $file = join q[/], $sdir, 'myfile';
  `touch $file`;
  my $new_file = join q[/], $sdir . '_old', 'myfile_invalid';
  $sm->_move_samplesheet_if_needed($file);
  ok(!-e $file, 'original file does not exist');
  ok(-e $new_file, 'moved file is in samplesheet_old directory');
}

{
  my $dir = tempdir(UNLINK => 1);
  mkdir "$dir/samplesheets";

  my $id_run = 47995;
  my $run_row = $schema->resultset('Run')->find($id_run);
  $run_row->update_run_status('run pending');
  is ($run_row->current_run_status_description(), 'run pending',
    "run $id_run should be picked up by the daemon");
  {
    local $CWD = $dir;
    diag `ls -l`;
    npg::samplesheet::auto->new(
      npg_tracking_schema => $schema,
      mlwh_schema         => $schema_wh,
      instrument_format   => 'NovaSeqX'
    )->process();
  }
  my $glob = q[*_47995_NVX1_A_ssbatch98292.csv];
  my @files = glob "$dir/samplesheets/$glob";
  is (@files, 1, 'one NovaSeqX samplesheet file is generated');
}

1;
