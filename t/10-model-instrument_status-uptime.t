use strict;
use warnings;
use Test::More tests => 44;
use t::util;
use English qw{-no_match_vars};
use DateTime;

use_ok('npg::model::instrument_status');

my $util = t::util->new({fixtures => 1});
$util->dbh->do("update instrument set iscurrent=0 where (id_instrument_format=11 or id_instrument_format=12);")  or die 'Failed to delete MiSeq instruments from the test DB '.$util->dbh->errstr;
diag 'To make this test work, MiSeq and HiSeqX instruments are set as not current';

my $model = npg::model::instrument_status->new({util => $util, id_instrument_status => 15});
#############
# number of days between today and the date the first statuses are in the test data
my $dt1 = DateTime->new(year => 2007, month => 9, day => 19);
my $dt2 = DateTime->now();
$dt2->set_hour(0);
$dt2->set_minute(0);
$dt2->set_second(0);
my $seconds = $dt2->subtract_datetime_absolute($dt1)->seconds();
my $days = $seconds/(60*60*24);
($days) = $days =~ /(\d+)\./xms;

my $instruments = $model->dates_instruments_up($days);
isa_ok($instruments, 'HASH', '$model->dates_instruments_up()');
foreach my $inst_name (sort keys %{$instruments}) {
  isa_ok($instruments->{$inst_name}, 'ARRAY', "$inst_name");
  foreach my $href (@{$instruments->{$inst_name}}) {
    isa_ok($href, 'HASH', 'array made of hashrefs');
  }
}

my $date_today = $dt2->ymd();
isa_ok($instruments->{IL9}->[0]->{up}, 'DateTime', 'first period on IL9 up');
like($instruments->{IL9}->[0]->{up}->datetime(), qr{2007-09-19}, 'first period on IL9 up');
isa_ok($instruments->{IL9}->[0]->{down}, 'DateTime', 'first period on IL9 down');
is($instruments->{IL9}->[0]->{down}->datetime(), q{2007-09-20T15:02:52}, 'first period on IL9 down');
is($instruments->{IL9}->[1]->{up}->datetime(), q{2007-10-02T11:02:52}, 'second period on IL9 up');
like($instruments->{IL9}->[1]->{down}->datetime(), qr{$date_today}, 'second period on IL9 down');

my $uptime = $model->uptime_for_all_instruments($days);
isa_ok($uptime, 'ARRAY', '$model->uptime_for_all_instruments()');
is($model->uptime_for_all_instruments($days), $uptime, '$model->uptime_for_all_instruments() cached ok');
is($uptime->[0]->[1], '0.00', 'percentage uptime for all instruments, first hour, is correct');
is($uptime->[0]->[0]->datetime, '2007-09-19T00:00:00', 'time of first is correct');
is($uptime->[14]->[1], '33.33', 'percentage uptime for all instruments, 14th hour, is correct');

my $table_rows = $model->average_percentage_uptime_for_day($days);
isa_ok($table_rows, 'ARRAY', '$model->average_percentage_uptime_for_day()');
is($model->average_percentage_uptime_for_day($days), $table_rows, '$model->average_percentage_uptime_for_day() cached ok');
is($table_rows->[0]->[0], '2007-09-19', 'first day is correct day');
is($table_rows->[0]->[1], '13.89', 'first day has correct percentage');
is($table_rows->[1]->[1], '31.11', 'second day has correct percentage');
is($table_rows->[2]->[1], '26.67', 'third day has correct percentage');

my $instrument_up_times = $model->instrument_percentage_uptimes($days);
isa_ok($instrument_up_times, 'ARRAY', '$model->instrument_percentage_uptimes()');
is($model->instrument_percentage_uptimes($days), $instrument_up_times, '$model->instrument_percentage_uptimes() cached ok');

my $greater_than_95_perc = ( $instrument_up_times->[0] > 95);
ok($greater_than_95_perc, 'full uptime greater than 95%');

is($instrument_up_times->[1], '100.00', 'last 30 days is 100%');


$model->{instrument_percentage_uptimes} = undef;
$instrument_up_times = $model->instrument_percentage_uptimes();

is($instrument_up_times->[0], '100.00', 'uptime of last 90 days is correct (default)');

1;
