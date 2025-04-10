use strict;
use warnings;
use File::Copy;
use Test::More tests => 3;
use Test::Exception;
use Test::Warn;
use File::Temp qw/ tempdir /;
use File::Path qw/ make_path /;
use File::Slurp;
use File::Spec::Functions qw( catfile catdir );

use t::dbic_util;

use_ok('Monitor::Elembio::RunFolder');

my $schema = t::dbic_util->new->test_schema();

subtest 'test run parameters loader' => sub {
    plan tests => 6;

    my $testdir = tempdir( CLEANUP => 1 );
    my $instrument_folder = q[AV244103];
    my $flowcell_id = q[1234567890];
    my $experiment_name = q[NT1234567B];
    my $rf_name = qq[20250325_${instrument_folder}_${experiment_name}];
    my $runfolder_path = catdir($testdir, $instrument_folder, $rf_name);
    make_path($runfolder_path);
    my $runparameters_file = catfile($runfolder_path, q[RunParameters.json]);
    open(my $fh, '>', $runparameters_file) or die "Could not open file '$runparameters_file' $!";
    print $fh <<"ENDJSON";
{
  "FileVersion": "5.0.0",
  "RunName": "$experiment_name",
  "RunType": "Sequencing",
  "RunDescription": "",
  "Side": "SideA",
  "FlowcellID": "$flowcell_id",
  "Date": "2025-03-25T11:43:59.792171889Z",
  "InstrumentName": "$instrument_folder",
  "RunFolderName": "$rf_name",
  "Cycles": {
    "R1": 151,
    "R2": 151,
    "I1": 8,
    "I2": 8
  },
  "ReadOrder": "I1,I2,R1,R2",
  "PlatformVersion": "3.2.0",
  "AnalysisLanes": "1+2",
  "LibraryType": "Linear",
  "Tags": null
}
ENDJSON
    close $fh;

    my $test = Monitor::Elembio::RunFolder->new( runfolder_path      => $runfolder_path,
                                                  npg_tracking_schema => $schema);
    isa_ok( $test, 'Monitor::Elembio::RunFolder' );
    is( $test->folder_name(), $rf_name, 'run_folder value correct' );
    is( $test->flowcell_id(), $flowcell_id, 'flowcell_id value correct' );
    #is( $test->instrument_id(), '', 'instrument_id value correct' );
    is( $test->side(), 'A', 'side value correct' );
    is( $test->cycle_count(), 318, 'actual cycle value correct' );
    is( $test->date_created(), '2025-03-25T11:43:59.792171889Z', 'date_created value correct' );
    #isa_ok( $test->tracking_run(), 'npg_tracking::Schema::Result::Run',
    #        'Object returned by tracking_run method' );
};

subtest 'test run parameters update' => sub {
    plan tests => 1;
    is (1, 1, 'pass');
};

1;
