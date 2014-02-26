#########
# Author:        jo3
# Maintainer:    $Author: jo3 $
# Created:       2010-06-15
# Last Modified: $Date: 2010-10-25 17:51:57 +0100 (Mon, 25 Oct 2010) $
# Id:            $Id: 34-monitor-srs.t 11474 2010-10-25 16:51:57Z jo3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/34-monitor-srs.t $
#
use strict;
use warnings;

use English qw(-no_match_vars);

use Test::More tests => 4;
use Test::Exception::LessClever;
use Test::MockObject;

use lib q{t};
use t::dbic_util;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 11474 $ =~ /(\d+)/msx; $r; };

local $ENV{dev} = 'test';
my $schema = t::dbic_util->new ( { db_to_use => q{mysql}, })->test_schema();


use_ok('Monitor::SRS');

my $test;

lives_ok { $test = Monitor::SRS->new( ident => 1, _schema => $schema ) }
         'Object creation ok';


my $folval = Test::MockObject->new();
$folval->fake_module(
                      'npg_tracking::illumina::run::folder::validation',
                      new => sub {$folval}
);

$folval->set_true('check');
ok( $test->validate_run_folder('This should pass'), 'Validation pass' );

$folval->set_false('check');
ok( !$test->validate_run_folder('This should fail'), 'Validation fail' );

1;

