use strict;
use warnings;
use Test::More tests => 11;
use Test::Deep;
use Test::Exception;
use Test::MockModule;
use Test::Warn;
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
    lives_ok { $test = Monitor::Staging->new( _schema => $schema ) }
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
    my $run = $schema->resultset('Run')->search({id_run => 5222})->next;
    $run or die 'need run 5222 in test db';
    $run->update_run_status('run cancelled'),
    my $test = Monitor::Staging->new( _schema => $schema );
    my $root = tempdir( CLEANUP => 1 );
    my @path = map { $root . $_ }
               qw(/IL5/outgoing/100713_IL24_0433
                  /IL12/analysis/100831_IL11_05222
                  /IL5/incoming/100713_IL24_04998
                  /IL4/incoming/071105_IL2_0095
                  /IL5/analysis/100713_IL12_04999
                  /IL999/incoming/080817_IL18_1234
                  /ILorHSany_sf20/incoming/100914_HS3_05281_A_205MBABXX );
    map { make_path $_} @path;
    my @live_incoming = $test->find_live($root);
    shift @path; shift @path;
    is( join(q[ ],sort @live_incoming), join(q[ ],sort @path), 'runfolders found in incoming and analysis');
}

1;
