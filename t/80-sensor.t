#########
# Author:        Jennifer Liddle (js10@sanger.ac.uk)
# Maintainer:    $Author: mg8 $
# Created:       2012_03_09
# Last Modified: $Date: 2012-03-29 17:11:11 +0100 (Thu, 29 Mar 2012) $
# Id:            $Id: 80-sensor.t 15402 2012-03-29 16:11:11Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/80-sensor.t $

use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use t::dbic_util;
#use XML::Simple;

use_ok('npg::sensors');
my $schema =  t::dbic_util->new->test_schema();

my $test = npg::sensors->new();
isa_ok( $test, 'npg::sensors', 'Correct class' );
$test = npg::sensors->new({schema => $schema});
isa_ok( $test, 'npg::sensors', 'Correct class' );

#my $data = $test->load_data();
#my $xml = new XML::Simple();
#my $ref = XMLin($data);
#my $sensors = $ref->{variable};
#foreach my $s (@$sensors) {
# diag "GUID: " . $s->{guid} . "\tTemperature: " . $s->{'double-val'} if exists $s->{'double-val'};
#}

lives_ok { $test->load_data() } 'loads data OK';
lives_ok { $test->post_data() } 'posts data OK';
lives_ok { $test->main() } 'runs main OK';

1;
