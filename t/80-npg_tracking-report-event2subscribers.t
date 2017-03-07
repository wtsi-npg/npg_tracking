use strict;
use warnings;
use Perl6::Slurp;
use DateTime;
use JSON;
use Test::More tests => 5;
use Test::Exception;
use Test::Warn;
use Log::Log4perl qw(:levels);
use File::Temp qw(tempdir);

use t::dbic_util;

local $ENV{'http_proxy'} = 'http://npgwibble.com'; #invalid proxy

my $logfile = join q[/], tempdir(CLEANUP => 1), 'logfile';
note "Log file: $logfile";
Log::Log4perl->easy_init({layout => '%d %-5p %c - %m%n',
                          level  => $INFO,
                          file   => $logfile,
                          utf8   => 1});

use_ok ('npg_tracking::report::event2subscribers');

my $schema = t::dbic_util->new()->test_schema();

foreach my $name (qw/Run RunStatus/) {
  my $file = "t/data/report/fixtures/${name}.json";
  my $data = from_json(slurp $file);
  my $rs = $schema->resultset($name);
  if ($name eq 'Run') {
    $rs->create($data);
  } else {
    for my $d (@{$data}) {
      $rs->create($d);
    }
  }
}

my $events_ug = $schema->resultset('Usergroup')->search({groupname => 'events'})->next();
ok( $events_ug, 'events usergroup exists');
my $events_ug_id = $events_ug->id_usergroup;
my $eng_ug = $schema->resultset('Usergroup')->search({groupname => 'engineers'})->next();
ok( $eng_ug, 'engineers usergroup exists');
my $eng_ug_id = $eng_ug->id_usergroup;

# delete all current members of both user groups
$schema->resultset('User2usergroup')->search({id_usergroup => [$events_ug_id, $eng_ug_id]})->delete();

# non-current user - should not appear in adressees
my $user = $schema->resultset('User')->create({username => 'ncu', iscurrent => 0});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $events_ug_id});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $eng_ug_id});

# current users, some members of one of the groups, some of both
# most have just usernames, the last has a full email address
$user = $schema->resultset('User')->create({username => 'cu1', iscurrent => 1});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $events_ug_id});
$user = $schema->resultset('User')->create({username => 'cu2', iscurrent => 1});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $events_ug_id});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $eng_ug_id});
$user = $schema->resultset('User')->create({username => 'cu3', iscurrent => 1});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $eng_ug_id});
$user = $schema->resultset('User')->create({username => 'acu4@some.com', iscurrent => 1});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $events_ug_id});
$schema->resultset('User2usergroup')->create({id_user => $user->id_user(), id_usergroup => $eng_ug_id});

local $ENV{'USER'} = $ENV{'USER'} || 'unknown';
my $shell_user = $ENV{'USER'};

my $id_run = 21915;

my $lims_summary = <<LIMS;
Lane 1: Samples
    QC1Hip-12209
    QC1Hip-12210
    QC1Hip-13615
    QC1Hip-13616
    QC1Hip-14336
    ... 17 samples in total

Lane 2: Samples
    QC1Hip-12209
    QC1Hip-12210
    QC1Hip-13615
    QC1Hip-13616
    QC1Hip-14336
    ... 17 samples in total

Lane 3: Samples
    QC1Hip-12209
    QC1Hip-12210
    QC1Hip-13615
    QC1Hip-13616
    QC1Hip-14336
    ... 17 samples in total

Lane 4: Samples
    QC1Hip-14329
    QC1Hip-14330
    QC1Hip-14361
    QC1Hip-14362
    QC1Hip-14573
    ... 17 samples in total

Lane 5: Samples
    QC1Hip-14329
    QC1Hip-14330
    QC1Hip-14361
    QC1Hip-14362
    QC1Hip-14573
    ... 17 samples in total

Lane 6: Samples
    QC1Hip-14329
    QC1Hip-14330
    QC1Hip-14361
    QC1Hip-14362
    QC1Hip-14573
    ... 17 samples in total

Lane 7: Samples
    QC1Hip-14324
    QC1Hip-14349
    QC1Hip-14582
    QC1Hip-14583
    QC1Hip-14821
    ... 17 samples in total

Lane 8: Samples
    CTTV0286207180
    CTTV0286207181
    CTTV0286207182
    CTTV0286207367
    CTTV0286207368
    ... 8 samples in total

LIMS

subtest 'run status event' => sub {
  plan tests => 11;
  
  my $status_row = $schema->resultset('RunStatus')->search({id_run => $id_run})->next();
  my $e = npg_tracking::report::event2subscribers->new(dry_run      => 1,
                                                       event_entity => $status_row);
  isa_ok ($e, 'npg_tracking::report::event2subscribers');
  ok ($e->dry_run, 'dry_run mode');
  is ($e->report_author(), $shell_user . '@sanger.ac.uk', 'report author');
  is ($e->template_name(), 'run_or_lane2subscribers', 'template name');
  is_deeply ($e->_subscribers(), [qw(acu4@some.com cu1@sanger.ac.uk cu2@sanger.ac.uk)],
    'correct ordered list of subscribers');
  is ($e->report_short(), 'Run 21915 was assigned status "run pending"', 'short report text');
  warning_like {$e->lims} qr/XML driver type is not allowed/, 'XML driver is not allowed';
  is (scalar @{$e->lims}, 0, 'Failed to get LIMs object');

  my $report = <<REPORT;
Run 21915 was assigned status "run pending" on 2017-02-08 11:49:39 by joe_events

NPG page for this run:
http://sfweb.internal.sanger.ac.uk:9000/run/21915

NPG, DNA Pipelines Informatics
REPORT
  is ($e->report_full($e->lims()), $report, 'full report text');

  local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} =  't/data/report/samplesheet_21915.csv';
  $e = npg_tracking::report::event2subscribers->new(dry_run      => 1,
                                                    event_entity => $status_row);
  is (scalar @{$e->lims}, 8, 'Retrieved LIMs object');

  $report = <<REPORT1;
Run 21915 was assigned status "run pending" on 2017-02-08 11:49:39 by joe_events
$lims_summary
NPG page for this run:
http://sfweb.internal.sanger.ac.uk:9000/run/21915

NPG, DNA Pipelines Informatics
REPORT1
  is ($e->report_full($e->lims()), $report, 'full report text with LIMs data');
};

subtest 'instrument status event' => sub {
  plan tests => 9;

  my $date = DateTime->now();
  my $date_as_string = $date->strftime('%F %T');
  my $status_row = $schema->resultset('InstrumentStatus')->create({
    id_instrument             => 6,
    id_instrument_status_dict => 4,
    id_user                   => 9,
    date                      => $date
  });

  my $e = npg_tracking::report::event2subscribers->new(dry_run      => 1,
                                                       event_entity => $status_row);
  isa_ok ($e, 'npg_tracking::report::event2subscribers');
  is ($e->report_author(), $shell_user . '@sanger.ac.uk', 'report author');
  is ($e->template_name(), 'instrument', 'template name');
  is_deeply ($e->_subscribers(), [qw(acu4@some.com cu2@sanger.ac.uk cu3@sanger.ac.uk)],
    'correct ordered list of subscribers');
  is ($e->report_short(), 'Instrument IL3 status changed to "wash performed"', 'short report text');
  warning_is {$e->lims} undef, 'no warning about LIMs driver';
  is (scalar @{$e->lims}, 0, 'LIMs object not required');

  my $report = <<REPORT2;
 Instrument IL3 status changed to "wash performed" on $date_as_string by joe_approver
NPG page for this instrument:
http://sfweb.internal.sanger.ac.uk:9000/instrument/6

NPG, DNA Pipelines Informatics
REPORT2
  is ($e->report_full($e->lims()), $report, 'full report text');

  $status_row->update({comment => 'my comment'});
  $e = npg_tracking::report::event2subscribers->new(dry_run      => 1,
                                                    event_entity => $status_row);
  $report = <<REPORT3;
 Instrument IL3 status changed to "wash performed" on $date_as_string by joe_approver. Comment: my comment
NPG page for this instrument:
http://sfweb.internal.sanger.ac.uk:9000/instrument/6

NPG, DNA Pipelines Informatics
REPORT3
  is ($e->report_full($e->lims()), $report, 'full report text with a comment');
};

1;
