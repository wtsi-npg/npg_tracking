use strict;
use warnings;
use Test::More tests => 28;
use Test::Deep;
use Test::Exception;

use_ok(q{npg_tracking::status});

my $timestamp = q{2014/07/10 13:42:10};
my $id_run = 1234;
my $status = q{analysis in progress};

{ 
  my $rls = npg_tracking::status->new(
      id_run => $id_run,
      lanes => [1],
      status => $status,
  );
  isa_ok( $rls, q{npg_tracking::status});
  is($rls->timestamp_format, '%Y/%m/%d %H:%M:%S', 'timestamp format correct');
  like( $rls->timestamp, qr{\d\d\/\d\d\/\d\d\ \d\d:\d\d:\d\d}, 'timestamp generated');
}

{
  my @lanes = (7, 6, 5);

  my $rls;
  lives_ok {
    $rls = npg_tracking::status->new(
      id_run => $id_run,
      lanes => \@lanes,
      status => $status,
      timestamp => $timestamp,
    );
  } q{object for eight lanes created ok};

  my $filename = q{analysis-in-progress_5_6_7.json};
  is($rls->filename, $filename, q{lane filename built correctly});

  my $s;
  lives_ok{ $s = $rls->freeze() } q{object serialized};
  my $o;
  lives_ok{ $o = npg_tracking::status->thaw($s) } q{object deserialized};
  is ($o->timestamp, $timestamp, 'timestamp correct');
  is ($o->status, $status, 'status correct');
  is ($o->id_run, $id_run, 'run id correct');
  cmp_deeply($o->lanes, \@lanes, 'lanes array correct'); 
}

{
  my @lanes = (1);

  my $rls;
  lives_ok {
    $rls = npg_tracking::status->new(
      id_run => $id_run,
      lanes => \@lanes,
      status => $status,
      timestamp => $timestamp,
    );
  } q{object for one lane created ok};

  my $filename = q{analysis-in-progress_1.json};
  is($rls->filename, $filename, qq{lane filename $filename built correctly});

  my $s;
  lives_ok{ $s = $rls->freeze() } q{object serialized};
  my $o;
  lives_ok{ $o = npg_tracking::status->thaw($s) } q{object deserialized};
  is ($o->timestamp, $timestamp, 'timestamp correct');
  is ($o->status, $status, 'status correct');
  is ($o->id_run, $id_run, 'run id correct');
  cmp_deeply($o->lanes, \@lanes, 'lanes array correct'); 
}

{
  my $status = q{analysis complete};

  my $rls;
  lives_ok {
    $rls = npg_tracking::status->new({
      id_run => $id_run,
      status => $status,
      timestamp => $timestamp,
    });
  } q{object for run created ok};

  my $run_filename = q{analysis-complete.json};
  is($rls->filename, $run_filename, q{run filename built correctly});

  my $s;
  lives_ok{ $s = $rls->freeze() } q{object serialized};
  my $o;
  lives_ok{ $o = npg_tracking::status->thaw($s) } q{object deserialized};
  is ($o->timestamp, $timestamp, 'timestamp correct');
  is ($o->status, $status, 'status correct');
  is ($o->id_run, $id_run, 'run id correct');
  cmp_deeply($o->lanes, [], 'lanes array is empty'); 
}

1;
