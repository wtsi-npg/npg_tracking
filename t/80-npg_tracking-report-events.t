use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Class::Load qw/try_load_class/;
use Log::Log4perl qw(:levels);
use File::Temp qw(tempdir);
use JSON;
use DateTime;
use List::Util qw/max/;
use Cwd qw/cwd/;

use npg_tracking::util::abs_path qw/abs_path/;
use t::dbic_util;

local $ENV{'no_proxy'}   = q[];
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

my ($mlwh_schema_loaded) = try_load_class('WTSI::DNAP::Warehouse::Schema');

my $schema_factory = t::dbic_util->new();
my $schema = $schema_factory->test_schema();
my $date           = DateTime->now();
my $date_as_string = $date->strftime('%F %T');
my $id_run         = 21915;
my $id_instrument  = 67;

my $shell_user    = $ENV{'USER'} || 'unknown';
my $report_author = $shell_user . '@sanger.ac.uk';

# Create run
my $run_json = qq[{"priority":"4","flowcell_id":"CAK4DANXX","batch_id":"51875","actual_cycle_count":"158","id_run":"$id_run","expected_cycle_count":"158","folder_path_glob":"/ILorHSany_sf46/*/","is_paired":"0","id_run_pair":null,"folder_name":"170208_HS32_21915_A_CAK4DANXX","id_instrument":"$id_instrument","team":"A","id_instrument_format":"10"}];
my $new_run = $schema->resultset('Run')->create(from_json($run_json));

my $events_ug = $schema->resultset('Usergroup')->search({groupname => 'events'})->next();
ok( $events_ug, 'events usergroup exists');
my $events_ug_id = $events_ug->id_usergroup;
my $eng_ug = $schema->resultset('Usergroup')->search({groupname => 'engineers'})->next();
ok( $eng_ug, 'engineers usergroup exists');
my $eng_ug_id = $eng_ug->id_usergroup;
# Delete all current members of both user groups
$schema->resultset('User2usergroup')->search({id_usergroup => [$events_ug_id, $eng_ug_id]})->delete();
# Create users, some members of one of the groups, some of both
# most have just usernames, the last has a full email address
my $user = $schema->resultset('User')->create({username => 'cu1', iscurrent => 1});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $events_ug_id});
$user = $schema->resultset('User')->create({username => 'cu3', iscurrent => 1});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $eng_ug_id});
$user = $schema->resultset('User')->create({username => 'acu4@some.com', iscurrent => 1});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $events_ug_id});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $eng_ug_id});

#
# mysql> select * from event_type, entity_type where entity_type.id_entity_type = event_type.id_entity_type;
# +---------------+---------------+----------------+----------------+-----------------------+-----------+
# | id_event_type | description   | id_entity_type | id_entity_type | description           | iscurrent |
# +---------------+---------------+----------------+----------------+-----------------------+-----------+
# |             1 | status change |              6 |              6 | run_status            |         1 |
# |             2 | annotation    |              1 |              1 | run                   |         1 |
# |             7 | status change |              9 |              9 | instrument_status     |         1 |
# |             8 | annotation    |              2 |              2 | instrument            |         1 |
# |             9 | annotation    |             10 |             10 | run_lane              |         1 |
# |            10 | annotation    |             15 |             15 | run_annotation        |         1 |
# |            11 | annotation    |             16 |             16 | run_lane_annotation   |         1 |
# |            12 | annotation    |             17 |             17 | instrument_annotation |         1 |
# +---------------+---------------+----------------+----------------+-----------------------+-----------+
#
# At the time of writing this new implementation (March 2017), previous implementation was creating
# events with the following id_event_type: 1, 7, 10, 11, 12. Events with id_event_type 2, 8, 9
# were last loaded in 2011.
#

# Create test data for entity_type and event_type tables
# and keep id_event_type values for future.

$schema->resultset('EntityType')->search({})->delete();
$schema->resultset('EventType')->search({})->delete();

my @entity_types = qw/ run_status
                       instrument_status
                       run_annotation
                       run_lane_annotation
                       instrument_annotation/;
my %entity2event = map { $_ => 1 } @entity_types;
for my $name (@entity_types) {
  my $entity = $schema->resultset('EntityType')->create({description =>  $name, iscurrent => 1});
  my $event  = $schema->resultset('EventType')->create({
    description    => ($name =~ /status/smx) ? 'status' : 'annotation',
    id_entity_type => $entity->id_entity_type()
  });
  $entity2event{$name} = $event->id_event_type();
}

subtest 'can create an object' => sub {
  plan tests => 7;
  my $e;
  lives_ok {
    $e = npg_tracking::report::events->new(dry_run     => 1,
                                      schema_npg  => $schema,
                                      schema_mlwh => undef)
  } 'created object with mlwh schema set to undefined explicitly';
  is($e->_template_dir_path(), abs_path(join(q[/], cwd(), 'data', 'npg_tracking_email', 'templates' )),
    'templates directory found');
  SKIP: {
    skip 'WTSI::DNAP::Warehouse::Schema is available', 2 unless !$mlwh_schema_loaded;
    lives_ok {
      $e = npg_tracking::report::events->new(dry_run    => 1,
                                             schema_npg => $schema)
    } 'created object with, WTSI::DNAP::Warehouse::Schema not available';
    lives_and ( sub {is $e->schema_mlwh, undef}, 'mlwh schema is undefined');
  };
  SKIP: {
    skip 'WTSI::DNAP::Warehouse::Schema is not available', 3 unless $mlwh_schema_loaded;
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

subtest 'process instrument events' => sub {
  plan tests => 9;

  my $status1 = $schema->resultset('InstrumentStatus')->create({
    id_instrument             => $id_instrument,
    id_instrument_status_dict => 1,
    id_user                   => 9,         
    date                      => $date      
  });
  my $status4 = $schema->resultset('InstrumentStatus')->create({
    id_instrument             => $id_instrument,
    id_instrument_status_dict => 4,
    id_user                   => 9,
    date                      => $date
  });
  my $annotation = $schema->resultset('Annotation')->create({
    id_user => 3,
    comment => 'New instrument annotation',
    date    => $date
  });
  my $iannotation = $schema->resultset('InstrumentAnnotation')
    ->create({
      id_annotation => $annotation->id_annotation(),
      id_instrument => $id_instrument
    });

  my $event_rs = $schema->resultset('Event');
  # delete all existing events
  $event_rs->search({})->delete();
  # create one processed event
  my $event_row = $event_rs->create({
    id_event_type     => $entity2event{'instrument_status'},
    date              => $date,
    description       => 'Some text',
    entity_id         => $status1->id_instrument_status(),
    id_user           => 6,
  });
  $event_row->mark_as_reported();
  ok ($event_row->notification_sent(), 'notification date set');

  my $e = npg_tracking::report::events->new(dry_run     => 1,
                                            schema_npg  => $schema,
                                            schema_mlwh => undef);
  my @counts;
  lives_ok {@counts = $e->process()} 'no error processing events (no new events)';
  ok (($counts[0] == 0) && ($counts[1] == 0), 'zero successes, zero failures');
  # create two unprocessed events
  my $event_row1 = $event_rs->create({
    id_event_type     => $entity2event{'instrument_status'},
    date              => $date,
    description       => 'Some text',
    entity_id         => $status4->id_instrument_status(),
    id_user           => 6,
  });
  ok (!$event_row1->notification_sent(), 'notification date not set');
  my $event_row2 = $event_rs->create({
    id_event_type     => $entity2event{'instrument_annotation'},
    date              => $date,
    description       => 'Some text',
    entity_id         => $iannotation->id_instrument_annotation(),
    id_user           => 6,                 
  });
  ok (!$event_row2->notification_sent(), 'notification date not set');

  lives_ok {@counts = $e->process()} 'no error processing events (two new events)';
  ok (($counts[0] == 2) && ($counts[1] == 0), 'two successes, zero failures');
  ok (!$event_row1->notification_sent(), 'dry run - notification date not set');
  ok (!$event_row2->notification_sent(), 'dry run - notification date not set');
};

subtest 'tolerance to failures' => sub {
  plan tests => 7;

  my $max_valid_id = max map { $_->id_instrument_status() }
                     $schema->resultset('InstrumentStatus')->search({})->all();
  
  my $event_rs      = $schema->resultset('Event');

  # create event for non-existing instrument status
  my $event_row = $event_rs->create({
    id_event_type     => $entity2event{'instrument_status'},
    date              => $date,
    description       => 'Some text',
    entity_id         => $max_valid_id + 1,
    id_user           => 6,
  });
  ok (!$event_row->notification_sent(), 'notification date not set');  

  my $e = npg_tracking::report::events->new(dry_run     => 1,
                                            schema_npg  => $schema,
                                            schema_mlwh => undef);
  my @counts;
  lives_ok {@counts = $e->process()} 'no error processing events (three new events)';
  ok (($counts[0] == 2) && ($counts[1] == 1), 'two successes, one failure');

  # create event for a non-existing event type
  my $event_row1 = $event_rs->create({
    id_event_type     => (max values %entity2event) + 1,
    date              => $date,
    description       => 'Some text',
    entity_id         => $max_valid_id,
    id_user           => 6,
  });
  ok (!$event_row1->notification_sent(), 'notification date not set');

  lives_ok {@counts = $e->process()} 'no error processing events (four new events)';
  ok (($counts[0] == 2) && ($counts[1] == 2), 'two successes, two failures');

  lives_ok { $event_row->delete();$event_row1->delete(); }
    'event rows that cause failures deleted';
};

subtest 'process run and runlane events' => sub {
  plan tests => 2;

  local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} = 't/data/report/samplesheet_21915.csv';
  local $ENV{'NPG_WEBSERVICE_CACHE_DIR'}    = 't/data/report';

  my $event_rs      = $schema->resultset('Event');
  my $rsd_rs        = $schema->resultset('RunStatusDict');
  # mark all existing events as notified
  map { $_->notification_sent ? 1 : $_->mark_as_reported()} $event_rs->search({})->all();

  # create two run status events
  my $entity = $schema->resultset('RunStatus')->create({
    id_user            => 8,
    id_run_status_dict => $rsd_rs->search(
      {description => 'qc complete'})->next()->id_run_status_dict(),
    date               => '2017-02-09 10:00:31',
    iscurrent          => 1,
    id_run             => $id_run
  });
  $event_rs->create({
    id_event_type     => $entity2event{'run_status'},
    date              => $date,
    description       => 'Some text',
    entity_id         => $entity->id_run_status(),
    id_user           => 6,
  });
  $entity = $schema->resultset('RunStatus')->create({
    id_user            => 8,
    id_run_status_dict => $rsd_rs->search(
      {description => 'analysis in progress'})->next()->id_run_status_dict(),
    date               => '2017-02-09 10:00:31',
    iscurrent          => 1,
    id_run             => $id_run
  });
  $event_rs->create({
    id_event_type     => $entity2event{'run_status'},
    date              => $date,
    description       => 'Some text',
    entity_id         => $entity->id_run_status(),
    id_user           => 6,
  });

  # create one run annotation event
  my $annotation = $schema->resultset('Annotation')->create({
    id_user => 3,
    comment => 'New run annotation',
    date    => $date
  });
  $entity = $schema->resultset('RunAnnotation')
    ->create({
      id_annotation => $annotation->id_annotation(),
      id_run        => $new_run->id_run()
    });
  $event_rs->create({
    id_event_type     => $entity2event{'run_annotation'},
    date              => $date,
    description       => 'Some text',
    entity_id         => $entity->id_run_annotation(),
    id_user           => 6,
  });

  # create one runlane annotation
  $annotation = $schema->resultset('Annotation')->create({
    id_user => 3,
    comment => 'New runlane annotation',
    date    => $date
  });
  my $runlane = $schema->resultset('RunLane')->create({
    id_run     => $id_run,
    position   => 2,
    tile_count => 12,
    tracks     => 4
  });
  $entity = $schema->resultset('RunLaneAnnotation')
    ->create({
      id_annotation => $annotation->id_annotation(),
      id_run_lane   => $runlane->id_run_lane()
    });
  $event_rs->create({
    id_event_type     => $entity2event{'run_lane_annotation'},
    date              => $date,
    description       => 'Some text',
    entity_id         => $entity->id_run_lane_annotation(),
    id_user           => 6,
  });

  my $e = npg_tracking::report::events->new(dry_run     => 1,
                                            schema_npg  => $schema,
                                            schema_mlwh => undef);
  my @counts;
  lives_ok {@counts = $e->process()} 'no error processing four new events)';
  ok (($counts[0] == 4) && ($counts[1] == 0), 'four successes, zero failures');
};

subtest 'tests with mlwarehouse driver' => sub {
  my $num_tests = 4;
  plan tests => $num_tests;

  SKIP: {
    skip 'WTSI::DNAP::Warehouse::Schema is not available',
      $num_tests unless $mlwh_schema_loaded;

    my $mlwh_schema = $schema_factory->create_test_db('WTSI::DNAP::Warehouse::Schema');
    local $ENV{'NPG_WEBSERVICE_CACHE_DIR'}    = 't/data/report';

    # We created a test database, but there are no data there
    my $e = npg_tracking::report::events->new(dry_run     => 1,
                                              schema_npg  => $schema,
                                              schema_mlwh => $mlwh_schema);
    my @counts;
    lives_ok {@counts = $e->process()} 'no error processing four new events';
    ok (($counts[0] == 0) && ($counts[1] == 4),
      'zero successes, four failures since no LIMs data available');

    # Load LIMs data for the flowcell the test run is linked to
    # only for one lane. Absence of data for lane 2 should cause
    # an error.

    my $study_row = '{"data_release_delay_period":null,"data_release_strategy":"open","remove_x_and_autosomes":0,"contains_human_dna":1,"uuid_study_lims":"5d526b00-38c6-11e4-bf88-68b59976a382","data_release_timing":"immediate","ega_policy_accession_number":null,"data_release_delay_reason":null,"separate_y_chromosome_data":0,"id_study_tmp":3265,"contaminated_human_dna":0,"name":"some name","study_title":"some title","prelim_id":null,"study_visibility":"Hold","ethically_approved":1,"data_destination":null,"id_lims":"SQSCP","id_study_lims":"3298","array_express_accession_number":null,"data_access_group":"hipsci","aligned":1,"ega_dac_accession_number":null,"state":"active","study_type":"Exome Sequencing","faculty_sponsor":"some person","data_release_sort_of_study":"genomic sequencing","last_updated":"2017-03-16 12:28:05","recorded_at":"2017-03-16 12:28:05"}';
    $mlwh_schema->resultset('Study')->create(from_json($study_row));

    my $sample_rows = '[
      {"common_name":"Homo sapiens","id_sample_lims":"2703313","name":"QC1Hip-14355","sanger_sample_id":"QC1Hip-14355","control":0,"id_sample_tmp":2682748,"uuid_sample_lims":"f0b7b7a0-36d5-0134-b2a2-005056a878e4","public_name":"HPSI0614i-lirf_5","id_lims":"SQSCP","taxon_id":9606,"last_updated":"2017-03-16 12:28:05","recorded_at":"2017-03-16 12:28:05"},
      {"taxon_id":9606,"id_lims":"SQSCP","control":0,"id_sample_tmp":2682749,"uuid_sample_lims":"f0b8f020-36d5-0134-b2a2-005056a878e4","public_name":"HPSI0614i-lirf_6","common_name":"Homo sapiens","id_sample_lims":"2703314","sanger_sample_id":"QC1Hip-14356","name":"QC1Hip-14356","last_updated":"2017-03-16 12:28:05","recorded_at":"2017-03-16 12:28:05"}
    ]';
   foreach my $entry (@{from_json($sample_rows)}) {
     $mlwh_schema->resultset('Sample')->create($entry);
   }
    my $flowcell_rows = '[
      {"tag_set_id_lims":"6","tag_sequence":"ATCACGTT","manual_qc":1,"entity_id_lims":"18515106","id_lims":"SQSCP","id_flowcell_lims":"51875","id_study_tmp":3265,"tag_set_name":"Sanger_168tags - 10 mer tags","id_library_lims":"DN474463P:A1","id_pool_lims":"NT898240N","id_sample_tmp":2682748,"legacy_library_id":18439946,"tag2_set_name":null,"priority":3,"team":"Illumina-HTP","flowcell_barcode":"CAK4DANXX","position":1,"is_spiked":1,"tag2_identifier":null,"forward_read_length":75,"is_r_and_d":0,"tag2_sequence":null,"pipeline_id_lims":"Agilent Pulldown","cost_code":"S0901","requested_insert_size_to":400,"external_release":1,"tag_index":1,"purpose":"standard","reverse_read_length":75,"bait_name":"Human all exon V5","tag2_set_id_lims":null,"entity_type":"library_indexed","requested_insert_size_from":100,"tag_identifier":"1","last_updated":"2017-03-16 12:28:05","recorded_at":"2017-03-16 12:28:05"},
      {"pipeline_id_lims":"Agilent Pulldown","tag2_sequence":null,"forward_read_length":75,"tag2_identifier":null,"is_r_and_d":0,"position":1,"is_spiked":1,"requested_insert_size_from":100,"tag_identifier":"2","bait_name":"Human all exon V5","entity_type":"library_indexed","tag2_set_id_lims":null,"tag_index":2,"purpose":"standard","reverse_read_length":75,"cost_code":"S0901","requested_insert_size_to":400,"external_release":1,"id_lims":"SQSCP","entity_id_lims":"18515106","id_flowcell_lims":"51875","manual_qc":1,"tag_set_id_lims":"6","tag_sequence":"CGATGTTT","team":"Illumina-HTP","flowcell_barcode":"CAK4DANXX","priority":3,"id_pool_lims":"NT898240N","id_sample_tmp":2682749,"legacy_library_id":18439958,"tag2_set_name":null,"tag_set_name":"Sanger_168tags - 10 mer tags","id_study_tmp":3265,"id_library_lims":"DN474463P:B1","last_updated":"2017-03-16 12:28:05","recorded_at":"2017-03-16 12:28:05"}
   ]';
   foreach my $entry (@{from_json($flowcell_rows)}) {
     $mlwh_schema->resultset('IseqFlowcell')->create($entry);
   }

    $e = npg_tracking::report::events->new(dry_run     => 1,
                                           schema_npg  => $schema,
                                           schema_mlwh => $mlwh_schema);
    lives_ok {@counts = $e->process()} 'no error processing four new events';
    ok (($counts[0] == 3) && ($counts[1] == 1),
      'three successes, one failure with wh LIMs data available');
  };
};

1;
