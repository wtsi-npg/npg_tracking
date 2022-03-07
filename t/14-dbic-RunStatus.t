use strict;
use warnings;
use Test::More tests => 18;
use Test::Exception;
use t::dbic_util;

use_ok( q{npg_tracking::Schema::Result::RunStatus} );

my $schema = t::dbic_util->new->test_schema();

my $rs;
lives_ok {
  $rs = $schema->resultset( q{RunStatus} )->search({
    id_run_status => 1,
  });
} q{obtain a result set ok};

isa_ok( $rs, q{DBIx::Class::ResultSet}, q{$rs} );

my $row = $rs->next();
isa_ok( $row, q{npg_tracking::Schema::Result::RunStatus});
is( $row->id_run(), 1, q{id_run obtained correctly} );
is( $row->description(), q{run pending}, q{description is correct} );
is($row->summary(), 'Run 1 was assigned status "run pending"',
  'correct summary string');
is($row->information(),
  'Run 1 was assigned status "run pending" on 2007-06-05 10:04:23 by joe_admin',
  'correct information string');
is_deeply([$row->event_report_types()], [], 'no additional reports');

my @followers_report_statuses = ('qc review pending', 'qc complete');
my @rows = $schema->resultset( q{RunStatusDict} )->search({
             description => \@followers_report_statuses})->all();
my @followers_report_statuses_ids = map {$_->id_run_status_dict() } @rows;
@followers_report_statuses = map {$_->description() } @rows;

my $count = scalar @followers_report_statuses;
is (scalar @followers_report_statuses_ids, $count, 'two ids');

my $i = 0;
while ($i < $count) {
  my $id     = $followers_report_statuses_ids[$i];
  my $status = $followers_report_statuses[$i];
  lives_ok { $row->update({id_run_status_dict => $id}) } "status updated to $status";
  is($row->summary(), qq{Run 1 was assigned status "$status"},
    'correct summary string');
  is($row->information(),
    qq{Run 1 was assigned status "$status" on 2007-06-05 10:04:23 by joe_admin},
    'correct information string');
  is_deeply([$row->event_report_types()], ['followers'],
    qq{followers report for status "$status"});
  $i++;
}

1;
