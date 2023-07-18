use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use Moose::Meta::Class;
use DateTime;

use npg_testing::db;

use_ok('npg::samplesheet::novaseq_xseries');

my $class = Moose::Meta::Class->create_anon_class(roles=>[qw/npg_testing::db/]);

my $schema_tracking = $class->new_object({})->create_test_db(
  q[npg_tracking::Schema], q[t/data/dbic_fixtures]
);

my $schema_wh = $class->new_object({})->create_test_db(
  q[WTSI::DNAP::Warehouse::Schema]
);

my $date = DateTime->now()->strftime('%y%m%d');

subtest 'create the generator object, test simple attributes' => sub {
  plan tests => 14;

  my $g = npg::samplesheet::novaseq_xseries->new(
    npg_tracking_schema => $schema_tracking,
    mlwh_schema         => $schema_wh,
  );
  isa_ok($g, 'npg::samplesheet::novaseq_xseries');
  is($g->dragen_max_number_of_configs, 4, 'correct default number of configs');
  throws_ok { $g->batch_id }
    qr/Run ID is not supplied, cannot get LIMS batch ID/,
    'error retrieving batch id';

  $g = npg::samplesheet::novaseq_xseries->new(
    npg_tracking_schema => $schema_tracking,
    mlwh_schema         => $schema_wh,
    id_run              => 47446,
  );
  throws_ok { $g->batch_id }
    qr/The database record for run 47446 does not exist/,
    'error retrieving batch ID in the absence of a database record for a run';

  $g = npg::samplesheet::novaseq_xseries->new(
    npg_tracking_schema => $schema_tracking,
    mlwh_schema         => $schema_wh,
    batch_id            => 97071,
  );
  like($g->run_name, qr/\Assbatch97071_[\w]+\Z/,
    'run name when id_run is not given');
  like($g->file_name, qr/\A${date}_ssbatch97071_[\w]+\.csv\Z/,
    'samplesheet file name when id_run is not given');

  my $run_row = $schema_tracking->resultset('Run')->create({
    id_run => 47446,
    id_instrument_format => 12,
    id_instrument => 69,
    team => 'A'
  });

  $g = npg::samplesheet::novaseq_xseries->new(
    npg_tracking_schema => $schema_tracking,
    mlwh_schema         => $schema_wh,
    id_run              => 47446,
    batch_id            => 97071,
  );
  throws_ok { $g->file_name } qr/Slot is not set for run 47446/,
    'error when the slot is unknown';

  for my $slot (qw(A B)) {
    my $tag = 'fc_slot' . $slot;
    $run_row->set_tag('pipeline', $tag);
    $g = npg::samplesheet::novaseq_xseries->new(
      npg_tracking_schema => $schema_tracking,
      mlwh_schema         => $schema_wh,
      id_run              => 47446,
      batch_id            => 97071,
    );
    is ($g->file_name, "${date}_NVX1_47446_${slot}_ssbatch97071.csv",
      'correct file name is generated');
    is($g->run_name, "47446_NVX1_${slot}",
      'run name is constructed from run ID when possible');
    if ($slot eq 'A') {
      $run_row->unset_tag($tag);
    }
  }

  $g = npg::samplesheet::novaseq_xseries->new(
    npg_tracking_schema => $schema_tracking,
    mlwh_schema         => $schema_wh,
    id_run              => 47446,
  );
  throws_ok { $g->file_name }
    qr/Batch ID is not set in the database record for run 47446/,
    'Error when batch id is unset and unknown';

  $run_row->update({batch_id => 99888});
  $g = npg::samplesheet::novaseq_xseries->new(
    npg_tracking_schema => $schema_tracking,
    mlwh_schema         => $schema_wh,
    id_run              => 47446,
  );
  is ($g->file_name, "${date}_NVX1_47446_B_ssbatch99888.csv",
    'correct file name is generated');

  $run_row->update({id_instrument_format => 10, id_instrument => 68});
  $g = npg::samplesheet::novaseq_xseries->new(
    npg_tracking_schema => $schema_tracking,
    mlwh_schema         => $schema_wh,
    id_run              => 47446,
  );
  throws_ok { $g->file_name }
    qr/Instrument model is not NovaSeq X Series/,
    'error when the run is registered on the wrong instrument model';
};

1;
