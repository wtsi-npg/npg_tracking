use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception::LessClever;
use Test::MockObject;
use t::dbic_util;

local $ENV{dev} = 'test';
my $schema = t::dbic_util->new->test_schema();


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

