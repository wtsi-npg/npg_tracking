#########
# Author:        jo3
# Maintainer:    $Author: jo3 $
# Created:       2010-05-25
# Last Modified: $Date: 2010-10-25 15:41:02 +0100 (Mon, 25 Oct 2010) $
# Id:            $Id: 34-monitor-cbot-run_list.t 11472 2010-10-25 14:41:02Z jo3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/34-monitor-cbot-run_list.t $
#
use strict;
use warnings;

use English qw(-no_match_vars);
use Perl6::Slurp;

use Test::More tests => 6;
use Test::Exception::LessClever;

use t::dbic_util;
use t::useragent;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 11472 $ =~ /(\d+)/msx; $r; };

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
