use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;

use t::dbic_util;

my $schema = t::dbic_util->new->test_schema();

subtest 'find a run using given attributes' => sub {
  plan tests => 9;

  my $rs = $schema->resultset('Run');
  ok ($rs->can('find_with_attributes'),
    'method find_with_attributes is implemented');

  throws_ok { $rs->find_with_attributes() }
    qr/One of flowcell ID \(or barcode\) or instrument name is undefined/,
    'error if arguments are missing';

  throws_ok { $rs->find_with_attributes(
    '2427452508', 'AV2222', '20250127_AV244103_NT1850075L') }
    qr/Instrument with name or external name AV2222 does not exist/,
    'error if an instrument with a given name does not exist';
  
  my $irs = $schema->resultset('Instrument');
  $irs->search({name => 'NVX1'})->next()->update({external_name => 'LH00210'});  
  throws_ok { $rs->find_with_attributes(
    '2427452508', 'LH00210','20250127_AV244103_NT1850075L') }
    qr/Multiple instrument records with name or external name LH00210/,
    'error if multiple instruments with a given external name are present';

  my $run = $rs->find_with_attributes(
    '2427452509', 'AV244103', '20250126_AV244103_NT1850075L');
  ok (!defined($run), 'an undefind value is returned for a non-tracked run');
  $run = $rs->find_with_attributes(
    '2427452508', 'AV244103', '20250127_AV244103_1234_NT1850075L');
  is ($run->id_run, 50000, 'correct run is found using instrument external name');
  $run = $rs->find_with_attributes(
    '2427452508', 'AV2', '20250127_AV244103_1234_NT1850075L');
  is ($run->id_run, 50000, 'correct run is found using instrument name');  
  
  $run = $rs->find_with_attributes('2427452508', 'AV2');
  is ($run->id_run, 50000, 'correct run is found, run folder name is not given');
  
  $rs->create({
    actual_cycle_count => 200,
    expected_cycle_count => 318,
    flowcell_id => '2427452508',
    folder_name => '20250127_AV244103_1234_NT1850075K',
    id_instrument => 100,
    id_instrument_format => 19,
    is_paired => 1,
    priority => 1,
    team => 'SR'  
  }); # create a new run with the same run folder name and instrument id as
      # run 50000
  throws_ok { $rs->find_with_attributes('2427452508', 'AV2') }
   qr/Multiple run records for flowcell 2427452508, instrument AV2/,
   'error if a duplicate run record is present';
};
