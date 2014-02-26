#########
# Author:        jo3
# Maintainer:    $Author: jo3 $
# Created:       2010-06-15
# Last Modified: $Date: 2010-11-03 10:58:34 +0000 (Wed, 03 Nov 2010) $
# Id:            $Id: 34-monitor-srs-ftp.t 11585 2010-11-03 10:58:34Z jo3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/34-monitor-srs-ftp.t $
#

# NOTE. Errors like the following:
#sh: -c: line 0: syntax error near unexpected token `0xa3242b8'
#sh: -c: line 0: `Test::FTP::Server::Server=HASH(0xa3242b8)'
#           ...come from IO::All::FTP


use strict;
use warnings;

use Carp;
use English qw(-no_match_vars);
use File::chdir;
use File::Copy;
use Perl6::Slurp;
use IPC::System::Simple; #needed for Fatalised/autodying system()
use autodie qw(:all);

use Test::More tests => 28;
use Test::Deep;
use Test::Exception::LessClever;
use Test::MockModule;
use Test::Warn;

use lib q{t};
use t::dbic_util;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 11585 $ =~ /(\d+)/msx; $r; };
Readonly::Scalar my $PORT => 11_223;


use_ok('Monitor::SRS::FTP');

my $schema = t::dbic_util->new ( { db_to_use => q{mysql}, })->test_schema();
my $test;


$test = Monitor::SRS::FTP->new(
            ident    => 3_000_000_000,
            ftp_port => $PORT,
            _schema  => $schema,
);

throws_ok { $test->ftp_root() } qr/No[ ]database[ ]entry[ ]found/msx,
          'Croak without a matching db row';

lives_ok {
            $test = Monitor::SRS::FTP->new(
                        ident    => 3,
                        ftp_port => $PORT,
                        _schema  => $schema,
            )
         }
         'Object creation ok';


is(
    $test->ftp_root(),
    'ftp://ftp:srpipe@' . "IL1win:$PORT/",
    'Correct ftp address'
);


# Test our own custom all_dirs() method.
my $ftp_dir_string1 = <<'END';
06-01-10  03:34PM       <DIR>          Config
06-01-10  08:40PM       <DIR>          Data
06-02-10  11:34AM               106243 Events.log
06-02-10  11:34AM       <DIR>          EventScripts
06-01-10  04:47PM       <DIR>          Images
06-01-10  03:34PM                   29 PermissionTest.txt
06-01-10  04:48PM       <DIR>          Processed
06-02-10  12:43PM       <DIR>          Queued
06-01-10  03:57PM       <DIR>          ReadPrep1
10-07-09  02:29PM                48406 Recipe_GA2-PEM_2x76Cycle_v7.7.xml
END

my @expect_these_dirs1 = qw( Config Data   ReadPrep1 EventScripts
                             Images Queued Processed );

cmp_deeply(
    [@expect_these_dirs1],
    bag( $test->all_dirs($ftp_dir_string1) ),
    'Identify ftp subdirectories in listings - 1'
);


my $ftp_dir_string2 = <<'END';
total 446152
-rwxrw-r--  1 rta    solexa       127 2010-07-01 13:03 100701_IL3_04946.params
-rwxrw-r--  1 rta    solexa        23 2010-07-05 00:37 Basecalling_Netcopy_complete_READ1.txt
-rwxrw-r--  1 rta    solexa        23 2010-07-05 00:37 Basecalling_Netcopy_complete.txt
-rwxrw-r--  1 rta    solexa      6736 2010-07-05 00:00 CommandIndex.bin
drwxrwsr-x  3 rta    solexa      4096 2010-07-01 13:03 Config
drwxrwsr-x  7 rta    solexa      4096 2010-07-05 13:57 Data
drwxrwsr-x  2 rta    solexa      4096 2010-07-05 00:28 EventScripts
-rwxrw-r--  1 rta    solexa    202942 2010-07-04 23:51 Events.log
-rwxrw-r--  1 rta    solexa        23 2010-07-05 00:07 ImageAnalysis_Netcopy_complete_READ1.txt
-rwxrw-r--  1 rta    solexa        23 2010-07-05 00:07 ImageAnalysis_Netcopy_complete.txt
-rwxrw-r--  1 rta    solexa        23 2010-07-05 00:23 Image_Netcopy_complete.txt
drwxrwsr-x  2 rta    solexa       117 2010-07-08 13:13 InterOp
-rwxrw-r--  1 rta    solexa        29 2010-07-01 13:03 PermissionTest.txt
drwxrwsr-x  3 rta    solexa      4096 2010-07-05 00:28 ReadPrep1
drwxrwsr-x  3 rta    solexa      4096 2010-07-05 13:44 ReadPrep2
-rwxrw-r--  1 rta    solexa     44624 2009-10-07 14:29 Recipe_GA2-PEM2x_2x76Cycle_v7.7.xml
-rwxrw-r--  1 rta    solexa       208 2010-07-01 13:38 Restart_Read1_RTA.cmd
-rwxrw-r--  1 rta    solexa      7699 2010-07-01 14:25 Robocopy.log
-rwxrw-r--  1 rta    solexa       154 2010-07-01 13:03 RobocopyRunFolder.bat
-rwxrw-r--  1 rta    solexa   5401082 2010-07-05 00:23 RTA_RCM_perfmon_07011303_001.csv
-rwxrw-r--  1 rta    solexa       917 2010-07-01 13:03 RunInfo.xml
-rwxrw-r--  1 rta    solexa      1494 2010-07-01 13:23 RunLog_10-07-01_13-22-42.xml
-rwxrw-r--  1 rta    solexa 225559694 2010-07-05 00:23 RunLog_10-07-01_13-35-27.xml
-rw-rw-r--  1 srpipe solexa 225561117 2010-07-08 13:10 RunLog_concat.xml
drwxrwsr-x 10 rta    solexa        94 2010-07-01 21:00 Thumbnail_Images
END

my @expect_these_dirs2 = qw( Config  ReadPrep1 EventScripts     Data 
                             InterOp ReadPrep2 Thumbnail_Images );

cmp_deeply(
    [@expect_these_dirs2],
    bag( $test->all_dirs($ftp_dir_string2) ),
    'Identify ftp subdirectories in listings - 2'
);


is( $test->db_entry->latest_contact(), undef, 'Machine never contacted' );
lives_ok { $test->update_latest_contact() } 'Update contact timestamp';
like(
    $test->db_entry->latest_contact(),
    qr{\d{4}-[01]\d-[0-3]\d[ T][012]\d:[0-5]\d:[0-5]\d}msx,
    'Check stored value'
);


SKIP: {

    eval { require t::ftp_util;
           1; };

    ## no critic (ControlStructures::ProhibitPostfixControls)
    skip 'Test::FTP::Server needed for FTP tests', 19 if $EVAL_ERROR;
    ## use critic

    # Normal folder validation requires a db lookup. That's tested elsewhere
    # so let's use an unfussy mock-up.
    my $module = Test::MockModule->new('npg_tracking::illumina::run::folder::validation');
    $module->mock(
        'check',
        sub {
            return ( $_[0]->{run_folder} =~ m/\d+_(?:IL|HS)\d+_\d+/msx )
                   ? 1
                   : 0;
            }
    );

    my $ftp = t::ftp_util->new(
                user => 'ftp',
                pass => 'srpipe',
                root => $CWD . '/t/data/gaii/ftp',
                port => $PORT,
    );


    my $pid = $ftp->start();


    $test->ftp_root( 'ftp://no:such@' . "address:$PORT/" );

    throws_ok { $test->get_normal_run_paths() }
              qr/^Nothing at all found/ms,
              'Croak on empty listing';


    my $ftp_root = 'ftp://ftp:srpipe@' . "localhost:$PORT/";
    $test->ftp_root($ftp_root);

    ok( $test->can_contact() ne q{}, 'Can contact SRS ftp host' );

    cmp_deeply(
        [ $test->get_normal_run_paths() ],
        [
          $ftp_root . 'Runs/100611_IL2_0022',
          $ftp_root . 'Runs/100628_IL2_04929',
          $ftp_root . 'Runs/100914_HS3_05281_A_205MBABXX',
        ],
        'List regular run folders'
    );


    my $test_root = $ftp_root .'Runs/';

    lives_and { is( $test->is_run_completed( $test_root . '100628_IL2_04929' ),  1,
        'Run complete' ) } 'Run complete';
    lives_and { is( $test->is_run_completed( $test_root . '100611_IL2_0022' ), 0,
        'Run not complete' ) } 'Run not complete';

    throws_ok { $test->is_run_completed() }
              qr/Run[ ]folder[ ]not[ ]supplied/msx,
              'Croak if no argument supplied';

    warning_like { $test->is_run_completed( $test_root . 'gibberish' ) }
                 { carped => qr/^Could[ ]not[ ]read[ ]ftp:/msx },
                 'Carp if run folder is empty/not readable';


    is( $test->is_rta( $test_root . '100611_IL2_0022' ), 1,
        'Run is rta' );
    is( $test->is_rta( $test_root . '100628_IL2_04929' ), 0,
        'Run is not rta' );
    is( $test->is_rta( $test_root . 'this_is_not_a_run' ), undef,
        'Cannot determine if run is rta' );
    throws_ok { $test->is_rta() } qr/Run[ ]folder[ ]not[ ]supplied/msx,
              'Insist on run folder argument';


    my $ages_ago = q{2000-01-12 13:34:43};
    $test->db_entry->latest_contact($ages_ago);

    my $complete_run_path = $test_root . '100611_IL2_0022';
    my $mock_event_log    = 't/data/gaii/ftp/Runs/100611_IL2_0022/Events.log';
    my $first_log         = slurp 't/data/gaii/Events.log';

    open my $event_fh, q{>}, $mock_event_log;
    print {$event_fh} $first_log or croak $OS_ERROR;
    close $event_fh;

    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    is( $test->get_latest_cycle($complete_run_path), 27,
        'Latest cycle is 27' );


    my $update_log = slurp 't/data/gaii/Events.Update';
    open $event_fh, q{>>}, $mock_event_log;
    print {$event_fh} $update_log or croak $OS_ERROR;
    close $event_fh;

    is( $test->get_latest_cycle($complete_run_path), 28,
        'Time passes and it\'s 28' );

    ## use critic
    unlink $mock_event_log;

    isnt( $test->db_entry->latest_contact(), $ages_ago,
          'latest_contact field has been updated' );


    $ftp->stop($pid);


    # Hiseq tests

    $ftp = t::ftp_util->new(
                user => 'ftp',
                pass => 'srpipe',
                root => $CWD . '/t/data/hiseq/ftp/',
                port => $PORT,
    );

    $pid = $ftp->start();
    sleep 3;

    $test->ftp_root($ftp_root);

    ok ( $test->can_contact( 'Runs_D/', 'Runs_XZCV/' ) ne q{},
         'Can contact Hiseq ftp host' );

    my $prefer_test = $test->ftp_root() . 
        'Runs_E/100914_HS3_05281_A_205MBABXX';

    is( $test->get_latest_cycle($prefer_test), 152,
        'Parse StatusUpdate.xml when present' );

    my $temp_base = 't/data/hiseq/ftp/Runs_E/100914_HS3_05281_A_205MBABXX';

    mkdir $temp_base . '/Processed/L001/C155.1';

    is( $test->get_latest_cycle($prefer_test), 155,
        'Look in \'Processed\' directory for cycle count' );

    move( $temp_base . '/Processed/L001/C155.1',
          $temp_base . '/Images/L001/C157.1'
    ) || croak $OS_ERROR;

    lives_and { is( $test->get_latest_cycle($prefer_test), 157,
        'Look in \'Images\' directory for cycle count' ) } 'Look in \'Images\' directory for cycle count';

    rmdir $temp_base . '/Images/L001/C157.1';

    lives_and { is( $test->is_run_completed($prefer_test), 1,
        'Note ImageAnalysis_Netcopy_complete_Read2.txt when present' )} 'Note ImageAnalysis_Netcopy_complete_Read2.txt when present';
    
    $ftp->stop($pid);
}

note('Please ignore \'sh: -c: line 0: ...\' warnings');

1;
