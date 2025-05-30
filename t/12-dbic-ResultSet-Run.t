use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;

use t::dbic_util;

my $schema = t::dbic_util->new->test_schema();

subtest 'find a run using given attributes' => sub {
  plan tests => 9;

  my $rs = $schema->resultset('Run');
  ok ($rs->can('find_with_attributes'), 'method find_with_attributes is implemented');

  my @args = qw/20250127_AV244103_NT1850075L 2427452508 AV2/;
  while (@args) {
    pop @args;
    throws_ok { $rs->find_with_attributes(@args) }
      qr/One of runfolder name, flowcell ID or barcode or instrument name is undefined/,
      'error if some arguments are missing'
  }

  throws_ok { $rs->find_with_attributes(
    '20250127_AV244103_NT1850075L', '2427452508', 'AV2222') }
    qr/Instrument with name or external name AV2222 does not exist/,
    'error if an instrument with a given name does not exist';
  
  my $irs = $schema->resultset('Instrument');
  $irs->search({name => 'NVX1'})->next()->update({external_name => 'LH00210'});  
  throws_ok { $rs->find_with_attributes(
    '20250127_AV244103_NT1850075L', '2427452508', 'LH00210') }
    qr/Multiple instrument records with name or external name LH00210/,
    'error if multiple instruments with a given external name are present';

  my $run = $rs->find_with_attributes(
    '20250126_AV244103_NT1850075L', '2427452509', 'AV244103');
  ok (!defined($run), 'an undefind value is returned for a non-tracked run');
  $run = $rs->find_with_attributes(
    '20250127_AV244103_1234_NT1850075L', '2427452508', 'AV244103');
  is ($run->id_run, 50000, 'correct run is found using instrument external name');
  $run = $rs->find_with_attributes(
    '20250127_AV244103_1234_NT1850075L', '2427452508', 'AV2');
  is ($run->id_run, 50000, 'correct run is found using instrument name');  
};
