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
  q[npg_tracking::Schema] 
);

my $schema_wh = $class->new_object({})->create_test_db(
  q[WTSI::DNAP::Warehouse::Schema]
);

my $date = DateTime->now()->strftime('%y%m%d');

subtest 'create the generator object, test simple attributes' => sub {
  plan tests => 4;

  my $g = npg::samplesheet::novaseq_xseries->new(
    npg_tracking_schema => $schema_tracking,
    mlwh_schema         => $schema_wh,
  );
  isa_ok($g, 'npg::samplesheet::novaseq_xseries');
  throws_ok { $g->batch_id }
    qr/Run ID is not supplied, cannot get LIMS batch ID/,
    'error retrieving batch id';

  $g = npg::samplesheet::novaseq_xseries->new(
    npg_tracking_schema => $schema_tracking,
    mlwh_schema         => $schema_wh,
    id_run              => 47446,
  );
  throws_ok { $g->batch_id }
    qr/does not pass the type constraint/,
    'error retrieving batch ID in the absence of tracking run data';

  $g = npg::samplesheet::novaseq_xseries->new(
    npg_tracking_schema => $schema_tracking,
    mlwh_schema         => $schema_wh,
    batch_id            => 97071,
  );
  like($g->file_name, qr/\A${date}_ssbatch97071_[\w]+\.csv\Z/,
    'samplesheet file name when id_run is not given');    
};

1;
