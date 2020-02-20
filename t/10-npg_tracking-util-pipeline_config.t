use strict;
use warnings;
use Cwd;
use Test::More tests => 21;
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

throws_ok {
  t::pipeline_config->new(conf_path => 't/data/some_config')
} qr/Attribute \(conf_path\) does not pass the type constraint/,
  'cannot use non-exisitng conf directory';

my $c = t::pipeline_config->new(conf_path => 't/data/pipeline_config');
throws_ok { $c->product_conf_file_path() }
  qr/File t\/data\/pipeline_config\/product_release\.yml does not exist or is not readable/,
  'error when product config file is not available';
throws_ok  {
  t::pipeline_config->new(product_conf_file_path => 't/data/pipeline_config/some.yml')
} qr/Attribute \(product_conf_file_path\) does not pass the type constraint/,
  'cannot use non-exisitng product conf file';
my $pcfile = 't/data/pipeline_config/study_config_present/product_release.yml';
lives_ok {
  t::pipeline_config->new(product_conf_file_path => $pcfile)
} 'can supply a path to the existing product conf file';

$c = t::pipeline_config->new(conf_path => 't/data/pipeline_config/study_config_present');
is ( $c->product_conf_file_path(), $pcfile, 'product conf file path');
lives_ok { $c->_product_config() } 'product conf file path read OK';
is ($c->local_bin, join(q[/], getcwd(), 't'), 'local_bin path is correct');

$c = t::pipeline_config->new(product_conf_file_path => $pcfile, local_bin => 't/data');
isnt ($c->local_bin, 't/data', 'cannot set local_bin attr in the constructor');
is ($c->local_bin, join(q[/], getcwd(), 't'), 'local_bin path is correct');

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
  [ qr/Using the default configuration for study 700/ ],
  'warning about using the default configuration';
$expected = {s3 => {enable => '', notify => ''}, irods => {enable => 1, notify => ''}};
is_deeply ($study_hash, $expected, 'correct default data returned');
$study_hash = $c->study_config($l, 1);
is_deeply ($study_hash, {}, 'strict mode - an empty hash is returned');

my $pctfile = 't/data/pipeline_config/study_config_tertiary_present/product_release.yml';
$c = t::pipeline_config->new(conf_path => 't/data/pipeline_config/study_config_tertiary_present');
is ( $c->product_conf_file_path(), $pctfile, 'product conf file path');
lives_ok { $c->_product_config() } 'product conf file path read OK';
is ($c->local_bin, join(q[/], getcwd(), 't'), 'local_bin path is correct');
$study_hash = $c->study_config($l);
$expected = {study_id => 700, s3 => {enable => 1, notify => 1}, irods => {enable => '', notify => ''}, tertiary => {'Homo_sapiens' => {'GRCh37_53' => {'haplotype_caller' => {enable => 1, sample_chunking => 'hs37primary', sample_chunking_number => 24}}}}};
is_deeply ($study_hash, $expected, 'correct study with tertiary data returned');
$study_hash = $c->study_config($l, 1);
is_deeply ($study_hash, $expected, 'correct study with tertiary data returned in strict mode ');
1;
