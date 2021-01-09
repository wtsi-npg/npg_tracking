use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Moose::Meta::Class;

use_ok('npg_tracking::daemon::samplesheet::auto');

my $util = Moose::Meta::Class->create_anon_class(
             roles => [qw/npg_testing::db/])->new_object({});
my $schema_wh = $util->create_test_db(q[WTSI::DNAP::Warehouse::Schema],
                                      q[t/data/fixtures/wh]);
my $schema = $util->create_test_db(q[npg_tracking::Schema],
                                   q[t/data/fixtures/npg]);

{
  my $sm;
  lives_ok { $sm = npg_tracking::daemon::samplesheet::auto->new(
    npg_tracking_schema => $schema,
    mlwh_schema         => $schema_wh) } 'miseq monitor object';
  isa_ok($sm, 'npg_tracking::daemon::samplesheet::auto');
}

{
  is(npg_tracking::daemon::samplesheet::auto::_id_run_from_samplesheet(
      't/data/samplesheet/miseq_default.csv'), 10262,
      'id run retrieved from a samplesheet');
  lives_and { is npg_tracking::daemon::samplesheet::auto::_id_run_from_samplesheet('some_file'), undef}
      'undef reftuned for a non-exisitng samplesheet';
}

{
  my $dir = tempdir(UNLINK => 1);
  my $file = join q[/], $dir, 'myfile';
  `touch $file`;
  npg_tracking::daemon::samplesheet::auto::_move_samplesheet($file);
  ok(!-e $file, 'original file does not exist');
  ok(-e $file.'_invalid', 'file has been moved');

  my $sdir = join q[/],  $dir, 'samplesheet';
  mkdir $sdir;
  mkdir $sdir . '_old';
  $file = join q[/], $sdir, 'myfile';
  `touch $file`;
  my $new_file = join q[/], $sdir . '_old', 'myfile_invalid';
  npg_tracking::daemon::samplesheet::auto::_move_samplesheet($file);
  ok(!-e $file, 'original file does not exist');
  ok(-e $new_file, 'moved file is in samplesheet_old directory');
}

1;
