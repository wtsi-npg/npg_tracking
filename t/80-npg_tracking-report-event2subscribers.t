use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;
use Test::Warn;
use DateTime;
use JSON;
use Log::Log4perl qw(:levels);
use File::Temp qw(tempdir);

use t::dbic_util;

my $logfile = join q[/], tempdir(CLEANUP => 1), 'logfile';
note "Log file: $logfile";
Log::Log4perl->easy_init({layout => '%d %-5p %c - %m%n',
                          level  => $INFO,
                          file   => $logfile,
                          utf8   => 1});

my $footer = 'If you have any questions or need further assistance, ' .
'please feel free to reach out to a Scientific Service Representative at ' .
'dnap-ssr@sanger.ac.uk.' . "\n\n" . 'NPG on behalf of DNA Pipelines';

use_ok ('npg_tracking::report::event2subscribers');

my $template_dir = 'data/npg_tracking_email/templates';
my $schema = t::dbic_util->new()->test_schema();
my $date           = DateTime->now();
my $date_as_string = $date->strftime('%F %T');
my $id_run         = 21915;
my $id_instrument  = 67;

my $shell_user = $ENV{'USER'} || 'unknown';
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

my $lims_summary = <<LIMS;
Lane 1: Samples
    QC1Hip-12209
    QC1Hip-12210
    QC1Hip-13615
    QC1Hip-13616
    QC1Hip-14336
    ... 16 samples in total

Lane 2: Samples
    QC1Hip-12209
    QC1Hip-12210
    QC1Hip-13615
    QC1Hip-13616
    QC1Hip-14336
    ... 16 samples in total

Lane 3: Samples
    QC1Hip-12209
    QC1Hip-12210
    QC1Hip-13615
    QC1Hip-13616
    QC1Hip-14336
    ... 16 samples in total

Lane 4: Samples
    QC1Hip-14329
    QC1Hip-14330
    QC1Hip-14361
    QC1Hip-14362
    QC1Hip-14573
    ... 16 samples in total

Lane 5: Samples
    QC1Hip-14329
    QC1Hip-14330
    QC1Hip-14361
    QC1Hip-14362
    QC1Hip-14573
    ... 16 samples in total

Lane 6: Samples
    QC1Hip-14329
    QC1Hip-14330
    QC1Hip-14361
    QC1Hip-14362
    QC1Hip-14573
    ... 16 samples in total

Lane 7: Samples
    QC1Hip-14324
    QC1Hip-14349
    QC1Hip-14582
    QC1Hip-14583
    QC1Hip-14821
    ... 16 samples in total

Lane 8: Samples
    CTTV0286207180
    CTTV0286207181
    CTTV0286207182
    CTTV0286207367
    CTTV0286207368
    ... 7 samples in total

LIMS

subtest 'run status event' => sub {
  plan tests => 17;

  my $status_row = $schema->resultset('RunStatus')->create({
    id_user            => 8,
    id_run_status_dict => 1,
    date               => '2017-02-08 11:49:39',
    iscurrent          => 0,
    id_run             => $id_run
  });
  my $e = npg_tracking::report::event2subscribers->new(dry_run           => 1,
                                                       event_entity      => $status_row,
                                                       template_dir_path => $template_dir);
  isa_ok ($e, 'npg_tracking::report::event2subscribers');
  ok ($e->dry_run, 'dry_run mode');
  is ($e->report_author(), $report_author, 'report author');
  is ($e->template_name(), 'run_or_lane2subscribers', 'template name');
  is_deeply ($e->_subscribers(), [qw(acu4@some.com cu1@sanger.ac.uk cu2@sanger.ac.uk)],
    'correct ordered list of subscribers');
  is ($e->report_short(), 'Run 21915 was assigned status "run pending"', 'short report text');

  my $report = <<REPORT;
Run 21915 was assigned status "run pending" on 2017-02-08 11:49:39 by joe_events


NPG page for this run:
https://sfweb.internal.sanger.ac.uk:12443/perl/npg/run/21915


$footer
REPORT
  is ($e->report_full(), $report, 'full report text');

  local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} =  't/data/report/samplesheet_21915.csv';
  $e = npg_tracking::report::event2subscribers->new(dry_run           => 1,
                                                    event_entity      => $status_row,
                                                    template_dir_path => $template_dir);
  is (scalar @{$e->lims}, 8, 'Retrieved LIMs object');

  $report = <<REPORT1;
Run 21915 was assigned status "run pending" on 2017-02-08 11:49:39 by joe_events

$lims_summary
NPG page for this run:
https://sfweb.internal.sanger.ac.uk:12443/perl/npg/run/21915


$footer
REPORT1
  is ($e->report_full($e->lims()), $report, 'full report text with LIMs data');

  is (scalar @{$e->reports}, 1, 'One report generated');
  my $m = $e->reports->[0];
  isa_ok ($m, 'npg::util::mailer');
  is ($m->get_from(), $report_author, 'email from field');
  is ($m->get_subject(), $e->report_short(), 'email subject field');
  is ($m->get_body(), $report, 'email body field');
  is_deeply ($m->get_to(), $e->_subscribers(), 'email to field');
  ok ($m->can('mail'), 'mail method available');

  lives_ok { $e->emit() } 'report sent (dry run)';
};

subtest 'instrument status event' => sub {
  plan tests => 11;

  my $status_row = $schema->resultset('InstrumentStatus')->create({
    id_instrument             => $id_instrument,
    id_instrument_status_dict => 4,
    id_user                   => 9,
    date                      => $date
  });

  my $e = npg_tracking::report::event2subscribers->new(dry_run           => 1,
                                                       event_entity      => $status_row,
                                                       template_dir_path => $template_dir);
  isa_ok ($e, 'npg_tracking::report::event2subscribers');
  is ($e->report_author(), $report_author, 'report author');
  is ($e->template_name(), 'instrument', 'template name');
  is_deeply ($e->_subscribers(), [qw(acu4@some.com cu2@sanger.ac.uk cu3@sanger.ac.uk)],
    'correct ordered list of subscribers');
  is ($e->report_short(), 'Instrument HS8 status changed to "wash performed"', 'short report text');
  warning_is {$e->lims} undef, 'no warning about LIMs driver';
  is (scalar @{$e->lims}, 0, 'LIMs object not required');

  my $report = <<REPORT2;
Instrument HS8 status changed to "wash performed" on $date_as_string by joe_approver

NPG page for this instrument:
https://sfweb.internal.sanger.ac.uk:12443/perl/npg/instrument/HS8


$footer
REPORT2
  is ($e->report_full($e->lims()), $report, 'full report text');

  $status_row->update({comment => 'my comment'});
  $e = npg_tracking::report::event2subscribers->new(dry_run           => 1,
                                                    event_entity      => $status_row,
                                                    template_dir_path => $template_dir);
  $report = <<REPORT3;
Instrument HS8 status changed to "wash performed" on $date_as_string by joe_approver. Comment: my comment

NPG page for this instrument:
https://sfweb.internal.sanger.ac.uk:12443/perl/npg/instrument/HS8


$footer
REPORT3
  is ($e->report_full($e->lims()), $report, 'full report text with a comment');
  is (scalar @{$e->reports}, 1, 'One report generated');
  lives_ok { $e->emit() } 'report sent (dry run)';
};

subtest 'run annotation event' => sub {
  plan tests => 8;

  # user is joe_loader
  my $annotation = $schema->resultset('Annotation')->create({
    id_user => 3,
    comment => 'New run annotation',
    date    => $date,
  });
  my $run_annotation = $schema->resultset('RunAnnotation')->create({
    id_annotation => $annotation->id_annotation(),
    id_run        => $id_run
  });

  local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} =  't/data/report/samplesheet_21915.csv';
  my $e = npg_tracking::report::event2subscribers->new(dry_run           => 1,
                                                       event_entity      => $run_annotation,
                                                       template_dir_path => $template_dir);
  isa_ok ($e, 'npg_tracking::report::event2subscribers');
  ok ($e->dry_run, 'dry_run mode');
  is ($e->report_author(), $report_author, 'report author');
  is ($e->template_name(), 'run_or_lane2subscribers', 'template name');
  is_deeply ($e->_subscribers(), [qw(acu4@some.com cu1@sanger.ac.uk cu2@sanger.ac.uk)],
    'correct ordered list of subscribers');
  is ($e->report_short(), 'Run 21915 annotated by joe_loader', 'short report text');
  is (scalar @{$e->lims}, 8, 'Retrieved LIMs object');

  my $report = <<REPORT4;
Run 21915 annotated by joe_loader on $date_as_string - New run annotation

$lims_summary
NPG page for this run:
https://sfweb.internal.sanger.ac.uk:12443/perl/npg/run/21915


$footer
REPORT4
  is ($e->report_full($e->lims()), $report, 'full report text with LIMs data');
};

subtest 'runlane annotation event' => sub {
  plan tests => 8;

  my $runlane = $schema->resultset('RunLane')->create({
    id_run     => $id_run,
    position   => 2,
    tile_count => 12,
    tracks     => 4
  });
  # user is joe_loader
  my $annotation = $schema->resultset('Annotation')->create({
    id_user => 3,
    comment => 'New runlane annotation',
    date    => $date
  });
  my $runlane_annotation = $schema->resultset('RunLaneAnnotation')->create({
    id_annotation => $annotation->id_annotation(),
    id_run_lane   => $runlane->id_run_lane()
  });

  local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} =  't/data/report/samplesheet_21915.csv';
  my $e = npg_tracking::report::event2subscribers->new(dry_run           => 1,
                                                       event_entity      => $runlane_annotation,
                                                       template_dir_path => $template_dir);
  isa_ok ($e, 'npg_tracking::report::event2subscribers');
  ok ($e->dry_run, 'dry_run mode');
  is ($e->report_author(), $report_author, 'report author');
  is ($e->template_name(), 'run_or_lane2subscribers', 'template name');
  is_deeply ($e->_subscribers(), [qw(acu4@some.com cu1@sanger.ac.uk cu2@sanger.ac.uk)],
    'correct ordered list of subscribers');
  is ($e->report_short(), 'Run 21915 lane 2 annotated by joe_loader', 'short report text');
  is (scalar @{$e->lims}, 1, 'Retrieved LIMs object');

  my $report = <<REPORT5;
Run 21915 lane 2 annotated by joe_loader on $date_as_string - New runlane annotation

Lane 2: Samples
    QC1Hip-12209
    QC1Hip-12210
    QC1Hip-13615
    QC1Hip-13616
    QC1Hip-14336
    ... 16 samples in total


NPG page for this run:
https://sfweb.internal.sanger.ac.uk:12443/perl/npg/run/21915


$footer
REPORT5
  is ($e->report_full($e->lims()), $report, 'full report text with LIMs data');
};

subtest 'instrument annotation event' => sub {
  plan tests => 8;

  # user is joe_loader
  my $annotation = $schema->resultset('Annotation')->create({
    id_user => 3,
    comment => 'New instrument annotation',
    date    => $date
  });
  my $instrument_annotation = $schema->resultset('InstrumentAnnotation')->create({
    id_annotation => $annotation->id_annotation(),
    id_instrument => $id_instrument
  });

  my $e = npg_tracking::report::event2subscribers->new(dry_run           => 1,
                                                       event_entity      => $instrument_annotation,
                                                       template_dir_path => $template_dir);
  isa_ok ($e, 'npg_tracking::report::event2subscribers');
  is ($e->report_author(), $report_author, 'report author');
  is ($e->template_name(), 'instrument', 'template name');
  is_deeply ($e->_subscribers(), [qw(acu4@some.com cu2@sanger.ac.uk cu3@sanger.ac.uk)],
    'correct ordered list of subscribers');
  is ($e->report_short(), 'Instrument HS8 annotated by joe_loader', 'short report text');
  warning_is {$e->lims} undef, 'no warning about LIMs driver';
  is (scalar @{$e->lims}, 0, 'LIMs object not required');

  my $report = <<REPORT6;
Instrument HS8 annotated by joe_loader on $date_as_string - New instrument annotation

NPG page for this instrument:
https://sfweb.internal.sanger.ac.uk:12443/perl/npg/instrument/HS8


$footer
REPORT6
  is ($e->report_full($e->lims()), $report, 'full report text');
};

1;
