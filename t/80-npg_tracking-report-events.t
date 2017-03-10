use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use Class::Load qw/try_load_class/;
use Log::Log4perl qw(:levels);
use File::Temp qw(tempdir);
use JSON;

use t::dbic_util;

local $ENV{'http_proxy'} = 'http://npgwibble.com'; #invalid proxy
local $ENV{'HOME'}       = 't'; # ensures we cannot read production
                                # db credentials
my $logfile = join q[/], tempdir(CLEANUP => 1), 'logfile';
note "Log file: $logfile";
Log::Log4perl->easy_init({layout => '%d %-5p %c - %m%n',
                          level  => $INFO,
                          file   => $logfile,
                          utf8   => 1});

use_ok ('npg_tracking::report::events');

my $schema_factory = t::dbic_util->new();
my $schema = $schema_factory->test_schema();
my $date           = DateTime->now();
my $date_as_string = $date->strftime('%F %T');
my $id_run         = 21915;
my $id_instrument  = 67;

my $shell_user    = $ENV{'USER'} || 'unknown';
my $report_author = $shell_user . '@sanger.ac.uk';

# create run
my $run_json = qq[{"priority":"4","flowcell_id":"CAK4DANXX","batch_id":"51875","actual_cycle_count":"158","id_run":"$id_run","expected_cycle_count":"158","folder_path_glob":"/ILorHSany_sf46/*/","is_paired":"0","id_run_pair":null,"folder_name":"170208_HS32_21915_A_CAK4DANXX","id_instrument":"$id_instrument","team":"A","id_instrument_format":"10"}];
$schema->resultset('Run')->create(from_json($run_json));

my $events_ug = $schema->resultset('Usergroup')->search({groupname => 'events'})->next();
ok( $events_ug, 'events usergroup exists');
my $events_ug_id = $events_ug->id_usergroup;
my $eng_ug = $schema->resultset('Usergroup')->search({groupname => 'engineers'})->next();
ok( $eng_ug, 'engineers usergroup exists');
my $eng_ug_id = $eng_ug->id_usergroup;
# delete all current members of both user groups
$schema->resultset('User2usergroup')->search({id_usergroup => [$events_ug_id, $eng_ug_id]})->delete();
# create users, some members of one of the groups, some of both
# most have just usernames, the last has a full email address
my $user = $schema->resultset('User')->create({username => 'cu1', iscurrent => 1});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $events_ug_id});
$user = $schema->resultset('User')->create({username => 'cu3', iscurrent => 1});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $eng_ug_id});
$user = $schema->resultset('User')->create({username => 'acu4@some.com', iscurrent => 1});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $events_ug_id});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $eng_ug_id});

subtest 'can create an object' => sub {
  plan tests => 6;
  lives_ok {
    npg_tracking::report::events->new(dry_run     => 1,
                                      schema_npg  => $schema,
                                      schema_mlwh => undef)
  } 'created object with mlwh schema set to undefined explicitly';
  my $e;
  my ($loaded) = try_load_class('WTSI::DNAP::Warehouse::Schema');
  SKIP: {
    skip 'WTSI::DNAP::Warehouse::Schema is available', 2 unless !$loaded;
    lives_ok {
      $e = npg_tracking::report::events->new(dry_run    => 1,
                                             schema_npg => $schema)
    } 'created object with, WTSI::DNAP::Warehouse::Schema not available';
    lives_and ( sub {is $e->schema_mlwh, undef}, 'mlwh schema is undefined');
  };
  SKIP: {
    skip 'WTSI::DNAP::Warehouse::Schema is not available', 3 unless $loaded;
    lives_ok {
      $e = npg_tracking::report::events->new(dry_run    => 1,
                                             schema_npg => $schema)
    } 'created object when WTSI::DNAP::Warehouse::Schema is available';
    lives_and ( sub {is $e->schema_mlwh, undef}, 'mlwh schema is undefined');
    my $mlwh_schema = $schema_factory->create_test_db('WTSI::DNAP::Warehouse::Schema');
    lives_ok {
      npg_tracking::report::events->new(dry_run     => 1,
                                        schema_npg  => $schema,
                                        schema_mlwh => $mlwh_schema)
    } 'created object with mlwh schema object passed explicitly';
  };
};

1;
