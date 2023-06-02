use strict;
use warnings;
use Test::More tests => 10;
use Test::Exception;
use File::Temp qw/ tempdir /;
use File::Path qw/ make_path /;

use t::dbic_util;

BEGIN {
  local $ENV{'HOME'} = 't';
  use_ok('Monitor::Staging');
}

my $schema = t::dbic_util->new->test_schema(fixture_path => q[t/data/dbic_fixtures]);

{
    my $test;
    lives_ok { $test = Monitor::Staging->new( schema => $schema ) }
         'Object creation ok';
    throws_ok { $test->find_live() }
              qr/Top[ ]level[ ]staging[ ]path[ ]required/msx,
              'Require path argument';

    throws_ok { $test->find_live('/no/such/path') }
              qr/[ ]not[ ]a[ ]directory/msx, 'Require real path';
}

{
    my $tdir = tempdir( CLEANUP => 1 );
    my @staging_areas = ();
    foreach my $id (qw(18 22)) {
        my $dir = join q[/], $tdir, q[nfs], q[sf] . $id;
        make_path $dir;
        push @staging_areas, $dir;
    }
    my $mtest = Monitor::Staging->new( schema => $schema );

    throws_ok { $mtest->validate_areas() } qr/Empty argument list/,
        'error for no argument';
    throws_ok { $mtest->validate_areas(@staging_areas) }
        qr/Multiple staging areas cannot be processed/,
        'error for multiple staging directories';
    throws_ok { $mtest->validate_areas('/no/such/dir') }
        qr/Staging[ ]directory[ ]not[ ]found:[ ]/msx,
        'error for the non-existing staging directory';
    
    is ($mtest->validate_areas($staging_areas[0]), $staging_areas[0],
        'directory path is returned');
}

{
    my $run = $schema->resultset('Run')->search({id_run => 5222})->next;
    $run->update_run_status('run cancelled');

    my $test = Monitor::Staging->new( schema => $schema );

    my $root = tempdir( CLEANUP => 1 );
    my @path = map { $root . $_ }
               qw(/IL5/outgoing/100713_IL24_0433
                  /ILhome/analysis/150612_HS36_5222_A_C71G9ANXX
                  /ILorHSany_sf33/incoming/110811_HS17_06670_A_C04C3ACXX
                  /ILorHSorMS_sf45/incoming/120403_MS1_7826_A_MS0009139-00300
                  /ILorHSorMS_sf45/incoming/120403_MS1_7825_A_MS0009139-00300
                  /ILorHSany_sf44/analysis/110818_IL34_06699
                  /HSorHSany_sf40/incoming/110810_HS23_06668_B_D080FACXX );
    map { make_path $_ } @path;
    my @live_incoming;
    lives_ok { @live_incoming = $test->find_live($root) }, 'can find live';
    shift @path; # not in analysis | incoming
    shift @path; # run cancelled
    shift @path; # runfolder name mismatch against the db
    pop @path;   # looking at IL* only
    is( join(q[ ],sort @live_incoming), join(q[ ],sort @path),
        'runfolders found in incoming and analysis');
}

1;
