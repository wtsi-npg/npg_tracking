use strict;
use warnings;
use Test::More tests => 11;
use Test::Deep;
use Test::Exception::LessClever;
use Test::MockModule;
use Test::Warn;
use File::Temp qw/ tempdir /;
use File::Path qw/ make_path /;

use t::dbic_util;

use_ok('Monitor::Staging');

my $schema = t::dbic_util->new->test_schema();
my $test;

lives_ok { $test = Monitor::Staging->new( _schema => $schema ) }
         'Object creation ok';


{
    my $tdir = tempdir( CLEANUP => 1 );
    my @staging_areas = ();
    foreach my $id (qw(18 22 33 36)) {
      my $dir = join q[/], $tdir, q[nfs];
      mkdir $dir;
      $dir = join q[/], $dir, q[sf] . $id;
      mkdir $dir;
      push @staging_areas, $dir;
    }
    my $mtest = Monitor::Staging->new( _schema => $schema, known_areas => \@staging_areas);
    my @val_area_output;

    warning_is { @val_area_output = $mtest->validate_areas() }
               'Empty argument list',
               'Warn for no argument...';
    is( scalar @val_area_output, 0, '...and return an empty list' );

    warning_like {
                   @val_area_output = $mtest->validate_areas( 1, 100_000_000 )
                 }
                 qr/Parameter[ ]out[ ]of[ ]bounds:[ ]/msx,
                 'Warn for out of bounds index...';

    warning_like {
                   push @val_area_output,
                        $mtest->validate_areas( 2, '/no/such/dir' )
                 }
                 qr/Staging[ ]directory[ ]not[ ]found:[ ]/msx,
                 '   ...warn for directory not found...';

    warning_like { push @val_area_output, $mtest->validate_areas( 3, 3 ) }
                 qr/[ ]specified[ ]twice/msx,
                 '   ...warn for duplicate area...';

    cmp_bag( \@val_area_output, [ @{$mtest->known_areas}[1..3], ],
             '   ...causes of warnings filtered from output'
    );
}


{
    throws_ok { $test->find_live_incoming() }
              qr/Top[ ]level[ ]staging[ ]path[ ]required/msx,
              'Require path argument';

    throws_ok { $test->find_live_incoming('/no/such/path') }
              qr/[ ]not[ ]a[ ]directory/msx, 'Require real path';


    # npg_tracking::illumina::run::folder::validation uses npg::api, so call anything
    # matching a loose regex a pass.
    my $folval = Test::MockModule->new('npg_tracking::illumina::run::folder::validation');
    $folval->mock( 'check',
                   sub {
                    return ( $_[1] =~ m/\d{6}_(?:IL|HS)\d+_\d+/msx ) ? 1 : 0;
                   }
    );


    # This test is vulnerable. The method returns the values of a hash. The
    # test directory includes duplicate run folders for one run id, so we
    # can't rely on the same one being returned every time.
    
    my $MOCK_STAGING = 't/data/gaii/staging';
    my @live_incoming = $test->find_live_incoming($MOCK_STAGING);
    cmp_bag(
        \@live_incoming,
        [
          $MOCK_STAGING . '/IL5/incoming/100708_IL3_04998',
          $MOCK_STAGING . '/IL4/incoming/101026_IL4_0095',
          $MOCK_STAGING . '/IL5/incoming/100708_IL3_04999',
          $MOCK_STAGING . '/IL999/incoming/100622_IL3_01234',
          $MOCK_STAGING . '/IL12/incoming/100721_IL12_05222',
          $MOCK_STAGING . '/ILorHSany_sf20/incoming/100914_HS3_05281_A_205MBABXX',
        ],
        'The return list is correct'
    );

}


1;
