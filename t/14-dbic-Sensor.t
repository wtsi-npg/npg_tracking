#########
# Author:        Jennifer Liddle (js10@sanger.ac.uk)
# Maintainer:    $Author: mg8 $
# Created:       2012_03_09
# Last Modified: $Date: 2012-11-26 09:53:48 +0000 (Mon, 26 Nov 2012) $
# Id:            $Id: 14-dbic-Sensor.t 16269 2012-11-26 09:53:48Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/14-dbic-Sensor.t $

use strict;
use warnings;
use POSIX qw(strftime);
use Test::More tests => 6;
use Test::Exception;

use t::dbic_util;

use_ok('npg_tracking::Schema::Result::Sensor');

my $schema = t::dbic_util->new->test_schema();

my $test;
my $n;
my $n2;

my $test_sensor_id = 6;

lives_ok {
            $test = $schema->resultset('Sensor')->find
                        ( { id_sensor => $test_sensor_id } )
         }
         'Create test object';

isa_ok( $test, 'npg_tracking::Schema::Result::Sensor', 'Correct class' );

$test = $schema->resultset('Sensor')->search();
is($test,9,'Correct number of sensors');

$test = $schema->resultset('Sensor')->find({name => 'Temp 6'}, {columns => 'guid'});
is($test->guid, 'BC3A8BD_nbAlinkEnc_0_3_TEMP', 'Found correct guid');

$n2 = $schema->resultset('SensorDataInstrument')->count();

my $now = strftime("%Y-%m-%d %H:%M:%S", localtime);
$test = $schema->resultset('SensorData')->create({
  id_sensor => 1,
  date => $now,
  value => 22.4});

$test = $schema->resultset('SensorData')->create({
  id_sensor => 2,
  date => $now,
  value => -3});

$test = $schema->resultset('SensorData')->create({
  id_sensor => 3,
  date => $now,
  value => 100.01});

$n = $schema->resultset('SensorDataInstrument')->count();
is($n-$n2,3,'The trigger emulation seems to be working');

1;
