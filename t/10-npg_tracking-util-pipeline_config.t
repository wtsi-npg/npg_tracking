use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;
use Test::Warn;

use st::api::lims;

use_ok('npg_tracking::util::pipeline_config');

{
  package t::pipeline_config;
  use Moose;
  with 'npg_tracking::util::pipeline_config';
}

package main;

local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = 't/data/samplesheet/6946_extended.csv';

my $c = t::pipeline_config->new(conf_path => 't/data/pipeline_config');
throws_ok { $c->product_config() }
  qr/File t\/data\/pipeline_config\/product_release\.yml does not exist or is not readable/,
  'error when product config file is not available';

$c = t::pipeline_config->new(conf_path => 't/data/pipeline_config/study_config_present');
my $pc;
warning_like { $pc = $c->product_config() }
  qr/Reading product configuration from 't\/data\/pipeline_config\/study_config_present\/product_release\.yml'/,
  'file exists - message about location logged';
throws_ok { $c->study_config() }
  qr/st::api::lims object for a product is required/,
  'error when LIMs object arg is absent';
my $l = st::api::lims->new(id_run => 6946, position => 1, tag_index => 1);
my $study_hash = $c->study_config($l);
my $expected = {study_id => 700, s3 => {enable => 1, notify => 1}, irods => {enable => '', notify => ''}};
is_deeply ($study_hash, $expected, 'correct study data returned');
$study_hash = $c->study_config($l, 1);
is_deeply ($study_hash, $expected, 'correct study data returned in a strict mode');

$c = t::pipeline_config->new(conf_path => 't/data/pipeline_config/study_config_absent');
warnings_like { $study_hash = $c->study_config($l) }
  [ qr/Reading product configuration from 't\/data\/pipeline_config\/study_config_absent\/product_release\.yml'/,
    qr/Using the default configuration for study 700/ ],
  'warning about using the default configuration';
$expected = {s3 => {enable => '', notify => ''}, irods => {enable => 1, notify => ''}};
is_deeply ($study_hash, $expected, 'correct default data returned');
$study_hash = $c->study_config($l, 1);
is_deeply ($study_hash, {}, 'strict mode - an empty hash is returned');

1;