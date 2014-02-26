#########
# Author:        jo3
# Maintainer:    $Author: jo3 $
# Created:       2010-05-25
# Last Modified: $Date: 2010-10-25 15:41:02 +0100 (Mon, 25 Oct 2010) $
# Id:            $Id: 34-monitor-cbot-run_info.t 11472 2010-10-25 14:41:02Z jo3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/34-monitor-cbot-run_info.t $
#
use strict;
use warnings;

use English qw(-no_match_vars);
use Perl6::Slurp;

use Test::More tests => 15;
use Test::Exception::LessClever;

use t::dbic_util;
use t::useragent;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 11472 $ =~ /(\d+)/msx; $r; };

local $ENV{dev} = 'test';
my $mock_schema = t::dbic_util->new ( { db_to_use => q{mysql}, })->test_schema();

my $test;
my $dummy_cbot = 'cBot1';
my $run_label  = '091111_OEM-0B6VO7E14KH_0001';
my $dummy_url  = "http://$dummy_cbot.internal.sanger.ac.uk/RunInfo/$run_label";

my $user_agent = t::useragent->new( { is_success => 1,
                                      mock       => {
q{http://cBot1.internal.sanger.ac.uk/RunInfo/091111_OEM-0B6VO7E14KH_0001} => q{t/data/cbot/cBot1/RunInfo/091111_OEM-0B6VO7E14KH_0001.xml},
                                                    },
                                  } );

use_ok('Monitor::Cbot::RunInfo');

dies_ok { $test = Monitor::Cbot::RunInfo->new(
            _run_label => $run_label,
            _schema    => $mock_schema, )
        }
        'Require a cbot name';

dies_ok { $test = Monitor::Cbot::RunInfo->new(
            ident   => $dummy_cbot,
            _schema => $mock_schema, )
        }
        'Require a run_label';

$test = Monitor::Cbot::RunInfo->new(
        ident       => $dummy_cbot,
        _schema     => $mock_schema,
        _run_label  => $run_label,
        _user_agent => $user_agent,
);

is( $test->url(), $dummy_url, 'Correctly built url' );

is( $test->experiment_type(), 'PairedEnd',          'Return experiment type');
is( $test->flowcell_id(),     '700T1ABXX',          'Return flowcell id' );
is( $test->reagent_id(),      'GA1234567-PE1',      'Return reagent id' );
is( $test->start_time(),      '11/11/2009 5:14 PM', 'Return start time' );
is( $test->end_time(),        '11/11/2009 9:35 PM', 'Return end time' );
is( $test->user_name (),      'VVV',                'Return user name' );
is( $test->run_result(),      'Completed',          'Return run result' );
is(
    $test->result_message(),
    'Run completed successfully.',
    'Return result message'
);
is(
    $test->protocol_name(),
    'PE_Amp_Lin_Block_Hyb_v7.0',
    'Return protocol name'
);

my $current_run_info = $test->current_run_info();
my $xml_content = slurp "t/data/cbot/$dummy_cbot/RunInfo/$run_label.xml";

isa_ok(
    $current_run_info,
    'XML::LibXML::Document',
    'current_run_info output'
);

is(
    $test->latest_run_info->toString(),
    $xml_content,
    'Store the latest run info'
);


1;
