use strict;
use warnings;
use English qw(-no_match_vars);
use Readonly;
use File::Copy;
use File::Find;
use Perl6::Slurp;
use IPC::System::Simple; #needed for Fatalised/autodying system()
use autodie qw(:all);

use Test::More tests => 11;
use Test::Deep;
use Test::Exception::LessClever;
use Test::MockModule;
use Test::Warn;

use t::dbic_util;

Readonly::Scalar my $MOCK_STAGING  => 't/data/gaii/staging';
Readonly::Scalar my $NOT_RUNFOLDER => "$MOCK_STAGING/Not_a_valid_instdir";


use_ok('Monitor::SRS::Local');

my $schema = t::dbic_util->new->test_schema();
my $test;

lives_ok {
            $test = Monitor::SRS::Local->new( ident   => 3,
                                              _schema => $schema, )
         }
         'Object creation ok';

mkdir $NOT_RUNFOLDER unless -d $NOT_RUNFOLDER;


# Assume that there is appropriate testing of database look-ups for the run
# id for npg_tracking::illumina::run::folder::validation, and just make sure the folder
# names pass a regex.
{
   $test = Monitor::SRS::Local->new(
                ident        => 6,
                _schema      => $schema,
                glob_pattern => "$MOCK_STAGING/*/*/*",
    );

    my $module = Test::MockModule->new('npg_tracking::illumina::run::folder::validation');
    $module->mock(
        'check',
        sub {
            return ( $_[0]->{run_folder} =~ m/ \d+ _IL\d+_ \d+ /msx )
                   ? 1
                   : 0;
            }
    );

    # No requirement for matching e.g. m{staging/IL(\d+)/\d+_IL\1_\d+}msx
    cmp_deeply(
        [ $test->get_normal_run_paths() ],
        [
            "$MOCK_STAGING/IL3/incoming/100622_IL3_01234",
            "$MOCK_STAGING/IL5/incoming/100708_IL3_04998",
            "$MOCK_STAGING/IL5/incoming/100708_IL3_04999",
        ],
        'Retrieve list of valid run folders'
    );
}


# Further assume that npg_tracking::illumina::run::folder does adequate testing
# of the glob pattern that matches the live situation.
isnt( $test->glob_pattern(), undef, 'Retrieve glob pattern' );


{
    warning_like {
                    $test->
                        is_run_completed($NOT_RUNFOLDER)
                 }
                 { carped => qr/^No[ ]files[ ]in/msx },
                 'Warn that no files at all have been found';

    {
        local $SIG{__WARN__} = sub { 1; };

        is(
            $test->is_run_completed($NOT_RUNFOLDER),
            0,
            'Default to \'not complete\' when no information is available'
        );

    }

    is( $test->
            is_run_completed("$MOCK_STAGING/IL5/incoming/100621_IL5_01204"),
        1,
        'Report completed run' );

    is( $test->
            is_run_completed("$MOCK_STAGING/IL3/incoming/100622_IL3_01234"),
        0,
        'Report not completed run' );

    throws_ok { $test->is_run_completed() }
              qr/Run[ ]folder[ ]not[ ]supplied/msx,
              'Croak if no argument supplied';
}


{
    my $complete_run_path = "$MOCK_STAGING/IL3/incoming/100622_IL3_01234";

    ## no critic (ValuesAndExpressions::ProhibitMagicNumbers)
    is( $test->get_latest_cycle($complete_run_path), 37,
        'Latest cycle derived from \'Intensities\' directory' );

    my $status_xml = "$complete_run_path/Data/reports/StatusUpdate.xml";
    open my $temp_fh, q{>}, $status_xml  ;
    print {$temp_fh} '<ImgCycle>52</ImgCycle>' or carp $OS_ERROR;
    close $temp_fh;

    is( $test->get_latest_cycle($complete_run_path), 52,
        'Latest cycle derived from StatusUpdate.xml' );

    unlink $status_xml;
}

END {
  rmdir $NOT_RUNFOLDER unless !-d $NOT_RUNFOLDER;
}


1;
