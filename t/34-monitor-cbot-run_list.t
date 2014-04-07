use strict;
use warnings;

use English qw(-no_match_vars);
use Perl6::Slurp;

use Test::More tests => 6;
use Test::Exception::LessClever;

use t::dbic_util;
use t::useragent;

local $ENV{dev} = 'test';
my $mock_schema = t::dbic_util->new->test_schema();

my $test;
my $dummy_cbot = 'cBot1';
my $dummy_url  = "http://$dummy_cbot.internal.sanger.ac.uk/GetRunList";

my $user_agent = t::useragent->new( { is_success => 1,
                                      mock       => {
                          $dummy_url => q{t/data/cbot/cBot1/GetRunList.xml},
                                                    },
                                  } );

use_ok('Monitor::Cbot::RunList');

dies_ok { $test = Monitor::Cbot::RunList->new() } 'Require a cbot name';

$test = Monitor::Cbot::RunList->new(
    ident       => $dummy_cbot,
    _schema     => $mock_schema,
    _user_agent => $user_agent,
);

is( $test->url(), $dummy_url, 'Correctly built url' );

my $current_run_list = $test->current_run_list();
my $xml_content      = slurp "t/data/cbot/$dummy_cbot/GetRunList.xml";
my $latest_run_list  = $test->latest_run_list();

isa_ok( $latest_run_list,      'ARRAY' );
isa_ok( $latest_run_list->[0], 'XML::LibXML::Element' );

like(
    $latest_run_list->[0]->toString(),

    qr{
          <RunInformation>   \s*
          <Name> \S+ </Name> \s*
          </RunInformation>
      }msx,

    'Run info looks reasonable'
);


1;
