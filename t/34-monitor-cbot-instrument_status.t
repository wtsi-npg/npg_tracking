use strict;
use warnings;

use English qw(-no_match_vars);
use Perl6::Slurp;

use Test::More tests => 14;
use Test::Exception::LessClever;

use t::dbic_util;
use t::useragent;

local $ENV{dev} = 'test';
my $mock_schema = t::dbic_util->new->test_schema();

my $test;
my $dummy_cbot = 'cBot1';
my $dummy_url  = "http://$dummy_cbot.internal.sanger.ac.uk/InstrumentStatus";

my $user_agent = t::useragent->new( { is_success => 1,
                                      mock       => {
q{http://cBot1.internal.sanger.ac.uk/InstrumentStatus} => q{t/data/cbot/cBot1/InstrumentStatus.xml},
q{http://cBot2.internal.sanger.ac.uk/InstrumentStatus} => q{t/data/cbot/cBot2/InstrumentStatus.xml},
                                                    },
                                  } );

use_ok('Monitor::Cbot::InstrumentStatus');

dies_ok { $test = Monitor::Cbot::InstrumentStatus->new_with_options() }
        'Require a cbot name';

$test = Monitor::Cbot::InstrumentStatus->new(
                ident       => $dummy_cbot,
                _schema     => $mock_schema,
                _user_agent => $user_agent,
);

is( $test->url(), $dummy_url, 'Correctly built url' );

is( $test->instrument_name(),  'cBotX',   'Return instrument name' );
is( $test->instrument_state(), 'Running', 'Return instrument state' );
is( $test->type(),             'cBot',    'Return type' );
is( $test->is_enabled(),       1,         'Return is_enabled state' );
is( $test->machine_name(),     'CBOTX',   'Return machine name' );
is( $test->percent_complete(), 97,        'Return percent complete' );
is( $test->run_state(),        8,         'Return run_state' );

my $test2 = Monitor::Cbot::InstrumentStatus->new(
        ident       => 'cBot2',
        _schema     => $mock_schema,
        _user_agent => $user_agent,
);

is(
    $test2->percent_complete(),
    undef,
    'Return undef when percent complete is missing'
);

is( $test2->is_enabled(), 0, 'Correctly report false for is_enabled' );

my $current_status = $test->current_status();
my $xml_content    = slurp "t/data/cbot/$dummy_cbot/InstrumentStatus.xml";

isa_ok( $current_status, 'XML::LibXML::Document', 'current_status output' );

is(
    $test->latest_status->toString(),
    $xml_content,
    'Store the latest status'
);

1;
