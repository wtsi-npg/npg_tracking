use strict;
use warnings;
use Perl6::Slurp;
use JSON;
use Test::More tests => 4;
use Test::Exception;
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
$schema->resultset('User2usergroup')->search({id_usergroup => $events_ug_id})->delete();

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

subtest 'run status event' => sub {
  plan tests => 7;
  
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
  my $report = <<REPORT;
Run 21915 was assigned status "run pending" on 2017-02-08 11:49:39 by joe_events

NPG page for this run:
http://sfweb.internal.sanger.ac.uk:9000/run/21915

NPG, DNA Pipelines Informatics
REPORT
  is ($e->report_full(), $report, 'full report text');
};

1;
