use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use Test::Warn;
use DateTime;
use JSON;
use Log::Log4perl qw(:levels);
use File::Temp qw(tempdir);
use List::MoreUtils qw/all/;
use Perl6::Slurp;

use t::dbic_util;

local $ENV{'http_proxy'} = 'http://npgwibble.com'; #invalid proxy

my $logfile = join q[/], tempdir(CLEANUP => 1), 'logfile';
note "Log file: $logfile";
Log::Log4perl->easy_init({layout => '%d %-5p %c - %m%n',
                          level  => $INFO,
                          file   => $logfile,
                          utf8   => 1});

use_ok ('npg_tracking::report::event2followers');

my $schema = t::dbic_util->new()->test_schema();
my $date           = DateTime->now();
my $date_as_string = $date->strftime('%F %T');
my $id_run         = 21915;
my $id_instrument  = 67;

# create run
my $run_json = qq[{"priority":"4","flowcell_id":"CAK4DANXX","batch_id":"51875","actual_cycle_count":"158","id_run":"$id_run","expected_cycle_count":"158","folder_path_glob":"/ILorHSany_sf46/*/","is_paired":"0","id_run_pair":null,"folder_name":"170208_HS32_21915_A_CAK4DANXX","id_instrument":"$id_instrument","team":"A","id_instrument_format":"10"}];
$schema->resultset('Run')->create(from_json($run_json));

my $rsd_rs = $schema->resultset('RunStatusDict');

my $shell_user = $ENV{'USER'} || 'unknown';
my $report_author = $shell_user . '@sanger.ac.uk';

my $expected = [
  {3298 =>
    {users => [qw(user1@sanger.ac.uk user2@sanger.ac.uk user3@sanger.ac.uk user4@sanger.ac.uk user5@sanger.ac.uk)]}
  },
  {3299 =>
    {users => [qw(user1@sanger.ac.uk user2@sanger.ac.uk user3@sanger.ac.uk user4@sanger.ac.uk user5@sanger.ac.uk)]}
  },
  {3921 =>
    {users => [qw(user10@sanger.ac.uk user5@sanger.ac.uk user7@sanger.ac.uk user8@sanger.ac.uk user9@sanger.ac.uk)]}
  },
  {4350 =>
    {users => [qw(user2@sanger.ac.uk user3@sanger.ac.uk user6@sanger.ac.uk)]}
  },
  {4357 =>
    {users => [qw(user2@sanger.ac.uk user3@sanger.ac.uk user6@sanger.ac.uk)]}
  },
];

subtest 'run status qc review pending event' => sub {
  plan tests => 37;

  my $qc_review_pending_status_desc = 'qc review pending';
  my $qc_review_pending_status = $schema->resultset('RunStatus')->create({
    id_user            => 8,
    id_run_status_dict => $rsd_rs->search(
      {description => $qc_review_pending_status_desc})->next()->id_run_status_dict(),
    date               => '2017-02-08 11:49:39',
    iscurrent          => 0,
    id_run             => $id_run
  });

  my $e = npg_tracking::report::event2followers->new(dry_run      => 1,
                                                     event_entity => $qc_review_pending_status);
  isa_ok ($e, 'npg_tracking::report::event2followers');
  ok ($e->dry_run, 'dry_run mode');
  is ($e->template_name(), 'run_status2followers', 'template name');
  is ($e->report_short(), 'Run 21915 was assigned status "qc review pending"', 'short report text');
  warning_like {$e->lims} qr/XML driver type is not allowed/, 'XML driver is not allowed';
  is (scalar @{$e->lims}, 0, 'Failed to get LIMs object');
  lives_ok { $e->reports() } 'no error invoking reports accessor';
  is (scalar @{$e->reports()}, 0, 'no reports will be generated');
  lives_ok { $e->emit() } 'no error dealing with an empty report list';

  local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} =  't/data/report/samplesheet_21915.csv';
  $e = npg_tracking::report::event2followers->new(dry_run      => 1,
                                                  event_entity => $qc_review_pending_status);
  is (scalar @{$e->lims}, 8, 'retrieved LIMs object');
  is (scalar @{$e->reports()}, 5, 'five reports will be generated');

  my $subject = 'Study %i: Run 21915 was assigned status "qc review pending"';

  my $i = 0;
  foreach my $m (@{$e->reports()}) {

    my $info = $expected->[$i];
    my $study_id = (keys %{$info})[0];
    isa_ok ($m, 'npg::util::mailer');
    is ($m->get_from(), $report_author, 'email from field');
    is_deeply ($m->get_to(), $info->{$study_id}->{'users'}, 'email to field');
    is ($m->get_subject(), sprintf($subject, $study_id), 'email subject field');
    if ($i == 0) {
      is($m->get_body(), slurp 't/data/report/report_text_1', 'email body field');
    }
    ok ($m->can('mail'), 'mail method available');
    $i++;
  }
};

subtest 'run status qc complete event' => sub {
  plan tests => 22;

  my $qc_complete_status_desc = 'qc complete';
  my $qc_complete_status = $schema->resultset('RunStatus')->create({
    id_user            => 8,
    id_run_status_dict => $rsd_rs->search(
      {description => $qc_complete_status_desc})->next()->id_run_status_dict(),
    date               => '2017-02-09 10:00:31',
    iscurrent          => 1,
    id_run             => $id_run
  });

  local $ENV{'NPG_CACHED_SAMPLESHEET_FILE'} =  't/data/report/samplesheet_21915.csv';
  my $e = npg_tracking::report::event2followers->new(dry_run      => 1,
                                                     event_entity => $qc_complete_status);
  isa_ok ($e, 'npg_tracking::report::event2followers');
  ok ($e->dry_run, 'dry_run mode');
  is ($e->template_name(), 'run_status2followers', 'template name');
  is ($e->report_short(), 'Run 21915 was assigned status "qc complete"', 'short report text');
  is (scalar @{$e->lims}, 8, 'retrieved LIMs object');
  is (scalar @{$e->reports()}, 5, 'five reports will be generated');

  my $subject = 'Study %i: Run 21915 was assigned status "qc complete"';

  my $i = 0;
  foreach my $m (@{$e->reports()}) {

    my $info = $expected->[$i];
    my $study_id = (keys %{$info})[0];
    is ($m->get_from(), $report_author, 'email from field');
    is_deeply ($m->get_to(), $info->{$study_id}->{'users'}, 'email to field');
    is ($m->get_subject(), sprintf($subject, $study_id), 'email subject field');
    if ($i == 4) {
      is($m->get_body(), slurp 't/data/report/report_text_5', 'email body field');
    }
    $i++;
  }
};

1;
