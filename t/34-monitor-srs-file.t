# NOTE. Errors like the following:
#sh: -c: line 0: syntax error near unexpected token `0xa3242b8'
#sh: -c: line 0: `Test::FTP::Server::Server=HASH(0xa3242b8)'
# Come from IO::All::FTP


use strict;
use warnings;

use English qw(-no_match_vars);
use File::chdir;

use Test::More tests => 24;
use Test::Exception::LessClever;
use Readonly;

use t::dbic_util;

Readonly::Scalar my $PORT => 12_124;

my ( $ftp_test, $staging_test );
my $disposable_string;

BEGIN { use_ok('Monitor::SRS::File'); }

my $schema = t::dbic_util->new->test_schema();

dies_ok { Monitor::SRS::File->new( runfolder_path => '/abc/def' ) }
        'Constructor requires run_folder argument';

dies_ok { Monitor::SRS::File->new( run_folder     => 'abc' ) }
        'Constructor requires runfolder_path argument';


lives_ok {
            $ftp_test = Monitor::SRS::File->new(
                run_folder     => 'abc',
                runfolder_path => 'ftp://abc/def'
            )
         }
         'Successful instantiation (ftp)';

lives_ok {
            $staging_test = Monitor::SRS::File->new(
                run_folder     => '100708_IL3_04998',
                runfolder_path => 't/data/gaii/staging/IL5/incoming/'
                                . '100708_IL3_04998/',
            )
         }
         'Successful instantiation (staging)';


throws_ok { $staging_test->_fetch_recipe() }
          qr/^No recipe file found at/ms,
          'Croak if recipe not found in staging';


$staging_test = Monitor::SRS::File->new(
    run_folder     => '100622_IL3_01234',
    runfolder_path => 't/data/gaii/staging/IL3/incoming/100622_IL3_01234/',
);


lives_ok { $disposable_string = $staging_test->_fetch_recipe() }
         'No croak when the recipe file is found.';

ok( length $disposable_string > 0, 'Recipe found on staging is not empty' );

is( $staging_test->expected_cycle_count(), 160, 'Expected cycle count' );


lives_ok {
           $staging_test = Monitor::SRS::File->new(
              run_folder     => '100914_HS3_05281_A_205MBABXX',
              runfolder_path => 't/data/gaii/staging/ILorHSany_sf20/incoming/'
                              . '100914_HS3_05281_A_205MBABXX',
            )
         }
         'Successful instantiation (staging HiSeq)';

throws_ok { $staging_test->_fetch_recipe() }
          qr/^No recipe file found at/ms,
          'Croak as recipe not found in staging for HiSeq';

lives_ok { $disposable_string = $staging_test->_fetch_runinfo() }
         'No croak when the recipe file is found.';

ok( length $disposable_string > 0, 'RunInfo found on staging is not empty' );

is( $staging_test->expected_cycle_count(), 200, 'Expected cycle count' );

SKIP: {

    eval { require t::ftp_util };

    ## no critic (ControlStructures::ProhibitPostfixControls)
    skip 'Test::FTP::Server needed for FTP tests', 10
        if $EVAL_ERROR;
    ## use critic

    my $ftp = t::ftp_util->new(
                user => 'ftp',
                pass => 'srpipe',
                root => $CWD . '/t/data/gaii/ftp',
                port => $PORT,
    );

    my $pid = $ftp->start();

    lives_ok {
                $ftp_test = Monitor::SRS::File->new(
                                run_folder     => 'abc',
                                runfolder_path => 'ftp://ftp:srpipe@'
                                                . "localhost:$PORT/Runs/"
                                                . '100628_IL2_04929/',
                )
             }
             'Successful instantiation (ftp)';

    throws_ok { $ftp_test->_fetch_recipe() }
              qr/^No[ ]recipe[ ]file[ ]found[ ]at/msx,
              'Croak if recipe not found on ftp site';


    $ftp_test = Monitor::SRS::File->new(
        run_folder     => 'abc',
        runfolder_path => 'ftp://ftp:srpipe@'
                        . "localhost:$PORT/Runs/"
                        . '100611_IL2_0022/',
    );


    $disposable_string = q{};
    lives_ok { $disposable_string = $ftp_test->_fetch_recipe() }
             'No croak when the recipe file is found.';

    ok(
        length $disposable_string > 0,
        'Recipe found on ftp site is not empty'
    );

    is( $ftp_test->expected_cycle_count(), 152, 'Expected cycle count' );


    lives_ok {
               $ftp_test = Monitor::SRS::File->new(
                   run_folder     => '100914_HS3_05281_A_205MBABXX',
                   runfolder_path => 'ftp://ftp:srpipe@'
                                   . "localhost:$PORT/Runs/"
                                   . '100914_HS3_05281_A_205MBABXX/',
               )
             }
             'Successful instantiation (ftp) HiSeq runfolder';

    throws_ok { $ftp_test->_fetch_recipe() }
              qr/^No[ ]recipe[ ]file[ ]found[ ]at/msx,
              'Croak if recipe not found on ftp site';

    $disposable_string = q{};
    lives_ok { $disposable_string = $ftp_test->_fetch_runinfo() }
             'No croak when the runinfo file is found.';

    ok( length $disposable_string > 0,
        'Runinfo found on ftp site is not empty' );

    is( $ftp_test->expected_cycle_count(), 200, 'Expected cycle count' );

    $ftp->stop($pid);
}

note('Please ignore \'sh: -c: line 0: ...\' warnings');

1;

