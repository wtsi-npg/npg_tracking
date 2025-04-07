use strict;
use warnings;
use File::Copy;
use Test::More tests => 6;
use Test::Exception;
use Test::Warn;
use File::Temp qw/ tempdir /;
use File::Path qw/ make_path /;
use File::Slurp;

use t::dbic_util;

use_ok('Monitor::Elembio::RunFolder');

my $schema = t::dbic_util->new->test_schema();
my $testdir = tempdir( CLEANUP => 1 );

subtest 'test run parameters loader' => sub {
    plan tests => 6;

    my $rf_name = q[];
    my $path = q[] . $rf_name;
    my $test = Monitor::Elembio::RunFolder->new( runfolder_path      => $path,
                                                  npg_tracking_schema => $schema, );
    isa_ok( $test, 'Monitor::Elembio::RunFolder' ); 
    is( $test->folder_name(), $rf_name, 'run_folder value correct' );
    is( $test->flowcell_id(), '', 'flowcell_id value correct' );
    is( $test->instrument_id(), '', 'instrument_id value correct' );
    is( $test->side(), '', 'side value correct' );
    is( $test->date_created(), '', 'date_created value correct' );
    #isa_ok( $test->tracking_run(), 'npg_tracking::Schema::Result::Run',
    #        'Object returned by tracking_run method' );  
};

subtest 'test run parameters update' => sub {
    plan tests => 0;
};

1;
