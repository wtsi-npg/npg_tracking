use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;
use DateTime;
use t::dbic_util;

use_ok( q{npg_tracking::Schema::Result::InstrumentStatus} );

my $schema = t::dbic_util->new->test_schema();

my $instrument = $schema->resultset( q{Instrument} )->search({name => 'HS1'})->next();
ok($instrument, 'instrument retrieved');

my $status = 'planned maintenance';
my $instrument_status_dict = $schema->resultset( q{InstrumentStatusDict} )->search(
  {description => $status})->next();

my $date = DateTime->now();
my $date_as_string = sprintf '%s', $date;
$date_as_string =~ s/T/ /;

my $status_row = $schema->resultset( q{InstrumentStatus} )->create({
  id_instrument             => $instrument->id_instrument(),
  id_instrument_status_dict => $instrument_status_dict->id_instrument_status_dict(),
  id_user                   => 8,
  iscurrent                => 1,
  date                      => $date
});

isa_ok( $status_row, q{npg_tracking::Schema::Result::InstrumentStatus});
is($status_row->summary(), qq[Instrument HS1 status changed to "$status"],
  'correct summary string');
my $info = qq[Instrument HS1 status changed to "$status" on $date_as_string by joe_events];
is($status_row->information(), $info, 'correct information string');
lives_ok { $status_row->update({comment => 'some comment'}) } 'added comment';
is($status_row->information(), $info . '. Comment: some comment',
  'correct information string');

1;
