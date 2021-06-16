use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;
use File::Temp qw/ tempdir /;
use Cwd;
use Log::Log4perl qw(:levels);
use List::MoreUtils qw/uniq/;
use t::dbic_util;

use_ok(q{npg_tracking::status});

my $id_run = 1234;
my $status = q{analysis in progress};
my $dir = tempdir(UNLINK => 1);
my $current = getcwd();
my $schema = t::dbic_util->new()->test_schema();

subtest 'create object' => sub {
  plan tests => 2;
  
  my $rls = npg_tracking::status->new(
      id_run => $id_run,
      lanes => [1],
      status => $status,
  );
  isa_ok( $rls, q{npg_tracking::status});
  like( $rls->timestamp,
    qr{\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d\+\d\d\d\d},
    'timestamp generated');
};

subtest 'multiple lanes status - JSON serialization' => sub {
  plan tests => 11;

  my @lanes = (7, 6, 5);
  my $rls = npg_tracking::status->new(
    id_run => $id_run,
    lanes => \@lanes,
    status => $status,
    timestamp => q{2014-07-10T13:42:10+0100},
  );

  my $filename = q{analysis-in-progress_5_6_7.json};
  is($rls->filename, $filename, q{lane filename built correctly});

  my $s;
  lives_ok{ $s = $rls->freeze() } q{object serialized};
  my $o;
  lives_ok{ $o = npg_tracking::status->thaw($s) } q{object deserialized};
  is ($o->timestamp, q{2014-07-10T13:42:10+0100}, 'timestamp correct');
  is ($o->status, $status, 'status correct');
  is ($o->id_run, $id_run, 'run id correct');
  is_deeply($o->lanes, \@lanes, 'lanes array correct');

  lives_ok { $o->to_file($dir) } 'serialization to a file';
  $filename = join(q[/], $dir, $filename);
  ok(-e $filename, 'file exists');
  my $new;
  lives_ok { $new = npg_tracking::status->from_file($filename)  }
    'object read from  file';
  isa_ok($new, q{npg_tracking::status});
};

subtest 'single lanes status - JSON serialization' => sub {
  plan tests => 7;

  my @lanes = (1);

  my $rls = npg_tracking::status->new(
    id_run => $id_run,
    lanes => \@lanes,
    status => $status,
    timestamp => q{2014-07-10T13:42:10+0000},
  );

  my $filename = q{analysis-in-progress_1.json};
  is($rls->filename, $filename, qq{lane filename $filename built correctly});

  my $s;
  lives_ok{ $s = $rls->freeze() } q{object serialized};
  my $o;
  lives_ok{ $o = npg_tracking::status->thaw($s) } q{object deserialized};
  is ($o->timestamp, q{2014-07-10T13:42:10+0000}, 'timestamp correct');
  is ($o->status, $status, 'status correct');
  is ($o->id_run, $id_run, 'run id correct');
  is_deeply($o->lanes, \@lanes, 'lanes array correct');
};

subtest 'single lanes status - JSON serialization' => sub {
  plan tests => 7;

  my $status = q{analysis complete};

  my $rls = npg_tracking::status->new(
    id_run => $id_run,
    status => $status
  );

  my $run_filename = q{analysis-complete.json};
  is($rls->filename, $run_filename, q{run filename built correctly});
  my $s;
  lives_ok{ $s = $rls->freeze() } q{object serialized};
  my $o;
  lives_ok{ $o = npg_tracking::status->thaw($s) } q{object deserialized};
  is ($o->status, $status, 'status correct');
  is ($o->id_run, $id_run, 'run id correct');
  is_deeply($o->lanes, [], 'lanes array is empty');
  chdir $dir;
  my $path = $o->to_file();
  ok(-e $path, 'file created in current directory');
  chdir $current;
};

subtest 'saving status to a database - errors' => sub {
  plan tests => 6;

  my $s = npg_tracking::status->new(id_run => 9999, status => 'some status');
  throws_ok {$s->to_database()}
    qr/Tracking database DBIx schema object is required/,
    'database handle is required';
  throws_ok {$s->to_database($schema)} qr/Run id 9999 does not exist/,
    'error saving status for non-existing run';
  $s = npg_tracking::status->new(id_run => 1, status => 'some status');
  throws_ok {$s->to_database($schema)}
    qr/Status 'some status' does not exist in RunStatusDict /,
    'error saving non-existing run status';
  $s = npg_tracking::status->new(
    id_run => 1, status => 'some status', timestamp => 'some time');
  throws_ok {$s->to_database($schema)}
    qr/Your datetime does not match your pattern/,
    'error converting timestamp to an object';
  $s = npg_tracking::status->new(
    id_run => 1, status => 'some status', lanes => [8, 7, 3]);
  throws_ok {$s->to_database($schema)} qr/Lane 3 does not exist in run 1/,
    'error saving status for a list of lanes that includes non-existing lane';
  $s = npg_tracking::status->new(
    id_run => 1, status => 'some status', lanes => [8, 7]);
  throws_ok {$s->to_database($schema)}
    qr/Status 'some status' does not exist in RunLaneStatusDict/,
    'error saving non-existing lane status';
};

subtest 'saving status to a database' => sub {
  plan tests => 14;

  Log::Log4perl->easy_init({layout => '%d %-5p %c - %m%n',
                            level  => $DEBUG,
                            file   => join(q[/], $dir, 'logfile'),
                            utf8   => 1});
  my $logger = Log::Log4perl->get_logger();  

  my $id_run = 9334;
  $schema->resultset('Run')->create({id_run        => $id_run,
                                     id_instrument => 48,
                                     team          => 'A'});
  foreach my $lane ((1 .. 4)) {
    $schema->resultset('RunLane')->create({id_run   => $id_run,
                                           position => $lane});
  }

  my @status_objs =
    map { npg_tracking::status->new(id_run => $id_run, status => $_) }
    ('analysis in progress', 'secondary analysis in progress');
  my $srs = $schema->resultset('RunStatus')->search({id_run => $id_run});
  $srs->delete;
  $schema->resultset('RunLaneStatus')->search({})->delete();

  $status_objs[0]->to_database($schema);
  my $rs = $srs->search({iscurrent => 1})->next()->run_status_dict;
  is ($rs->description(), 'analysis in progress', 'run status reset');

  $status_objs[1]->to_database($schema, $logger);
  $rs = $srs->search({iscurrent => 1})->next()->run_status_dict;
  is ($rs->description(), 'secondary analysis in progress', 'run status reset');
  $status_objs[1]->to_database($schema, $logger);
  $rs = $srs->search({iscurrent => 1})->next()->run_status_dict;
  is ($rs->description(), 'secondary analysis in progress',
    'run status not reset');

  is ($schema->resultset('RunLaneStatus')->search({})->count(), 0,
    'no lane status records are created');

  $schema->resultset('RunStatus')->search({})->delete();

  my $status_desc = 'analysis in progress';
  my $status_obj = npg_tracking::status->new(
    id_run => $id_run, status => $status_desc, lanes => [1,3]);
  $status_obj->to_database($schema);
  my @rl_statuses = $schema->resultset('RunLaneStatus')->search({})->all();
  is(scalar @rl_statuses, 2, 'two lane status records are created');
  my @descriptions = uniq map { $_->description } @rl_statuses;
  is (scalar @descriptions, 1, 'one unique status description');
  is ($descriptions[0], $status_desc, 'correct lane statuses are created');
  
  $status_desc = 'analysis complete';
  $status_obj = npg_tracking::status->new(
    id_run => $id_run, status => $status_desc, lanes => [1,2,3]);
  $status_obj->to_database($schema, $logger);
  is ($schema->resultset('RunLaneStatus')->search({})->count(), 5,
    'five lane status records in total');
  @rl_statuses = $schema->resultset('RunLaneStatus')
    ->search({iscurrent => 1})->all();
  is(scalar @rl_statuses, 3, 'three current lane status records');
  @descriptions = uniq map { $_->description } @rl_statuses;
  is (scalar @descriptions, 1, 'one unique status description'); 
  is ($descriptions[0], $status_desc, 'correct lane statuses are created');
    
  $status_obj->to_database($schema, $logger);
  @rl_statuses = $schema->resultset('RunLaneStatus')
    ->search({iscurrent => 1})->all();
  @descriptions = uniq map { $_->description } @rl_statuses;
  is (scalar @descriptions, 1, 'one unique status description');
  is ($descriptions[0], $status_desc, 'correct lane statuses are created');

  is ($schema->resultset('RunStatus')->search({})->count(), 0,
    'no run status records are created') ;  
};

END {
  eval {chdir $current};
}

1;
