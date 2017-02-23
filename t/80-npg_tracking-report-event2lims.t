use strict;
use warnings;
use Perl6::Slurp;
use JSON;
use Test::More tests => 24;
use Test::Exception;
use LWP::UserAgent;
use Log::Log4perl qw(:levels);
use File::Temp qw(tempdir);

use t::dbic_util;

note "\n***To avoid posting live, in this test LWP::UserAgent::post is replaced by a stub***\n\n";
*LWP::UserAgent::post = *main::post_nowhere;
sub post_nowhere {
  note "Posting nowhere...\n";
  return HTTP::Response->new(200);
}

my $logfile = join q[/], tempdir(CLEANUP => 1), 'logfile';
note "Log file: $logfile";
Log::Log4perl->easy_init({layout => '%d %-5p %c - %m%n',
                          level  => $INFO,
                          file   => $logfile,
                          utf8   => 1});

use_ok ('npg_tracking::report::event2lims');

local $ENV{'http_proxy'} = 'http://npgwibble.com'; #invalid proxy
local $ENV{'NPG_WEBSERVICE_CACHE_DIR'} = 't/data/report';

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

my $id_run = 21915;
my $status_row = $schema->resultset('RunStatus')->search({id_run => $id_run})->next();
ok ($status_row, 'run status row object defined');
my $status_desc = $status_row->description;
my $message = "Run $id_run : $status_desc";

my $e = npg_tracking::report::event2lims->new(dry_run      => 1,
                                              event_entity => $status_row);
isa_ok ($e, 'npg_tracking::report::event2lims');
ok ($e->dry_run, 'dry_run mode');
isa_ok ($e->lims->[0], 'st::api::lims');
is ($e->lims->[0]->driver_type, 'xml', 'xml driver type is used');
my $reports = $e->reports();
is (scalar @{$reports}, 8, 'eight reports');
my $r = $reports->[0];
isa_ok ($r, 'st::api::event');
is ($r->eventful_id, 11622971, 'request id for lane 1');
is ($r->eventful_type, 'Request', 'event type');
is ($r->location, 1, 'lane 1');
is ($r->identifier, $id_run, "run id $id_run");
is ($r->key, $status_desc, "run status $status_desc");
is ($r->message, $message, 'correct message');

$r = $reports->[-1];
isa_ok ($r, 'st::api::event');
is ($r->eventful_id, 11644855, 'request id for lane 8');
is ($r->eventful_type, 'Request', 'event type');
is ($r->location, 8, 'lane 8');
is ($r->identifier, $id_run, "run id $id_run");
is ($r->key, $status_desc, "run status $status_desc");
is ($r->message, $message, 'correct message');

lives_ok {$e->emit()} 'dry run, report posted';

$e = npg_tracking::report::event2lims->new(event_entity => $status_row);
ok (!$e->dry_run, 'dry_run is false by default');
lives_ok {$e->emit()} 'report posted';

1;
