use strict;
use warnings;
use Test::More tests => 91;
use Test::Exception;
use t::useragent;
use npg::api::util;
use DateTime;

sub test_instrument_stack {
   return  { 3 => { name => 'IL1', production => 1, official => 1 },
    4 => { name => 'IL2', production => 1, official => 1 },
    5 => { name => 'IL3', production => 1, official => 1 },
    6 => { name => 'IL4', },
    7 => { name => 'IL5', official => 1 },
    8 => { name => 'IL6', production => 1, official => 1 }, };
}

sub test_required_today {
  # arbritarily chosen date to be today
  return DateTime->new({ time_zone => 'UTC', year => 2009, month => 02, day => 04, hour => 10, minute => 13, second => 12 });
}
sub test_required_yesterday {
  # arbritarily chosen date to be yesterday
  return DateTime->new({ time_zone => 'UTC', year => 2009, month => 02, day => 03, hour => 10, minute => 13, second => 12 });
}
sub test_required_two_days_ago {
  # arbritarily chosen date to be yesterday
  return DateTime->new({ time_zone => 'UTC', year => 2009, month => 02, day => 02, hour => 10, minute => 13, second => 12 });
}
sub test_required_three_days_ago {
  # arbritarily chosen date to be yesterday
  return DateTime->new({ time_zone => 'UTC', year => 2009, month => 02, day => 01, hour => 10, minute => 13, second => 12 });
}

use_ok('npg::api::instrument_utilisation');
my $base_url = $npg::api::util::LIVE_BASE_URI;
{
  my $ua   = t::useragent->new({
        is_success => 1,
        mock => {
  $base_url.q{/instument.xml} => q{t/data/npg_api/npg/instrument_designation_list.xml},
  $base_url.q{/instrument} => q{t/data/npg_api/npg/instrument_designation_list.xml},
  $base_url.q{/run/recent/running/runs.xml} => q{t/data/rendered/run/recent/running/runs_4000_days.xml},
  $base_url.q{/instrument_status/up/down.xml} => q{t/data/rendered/instrument_status/list_up_down_xml.xml},
  $base_url.q{/run/1} => q{t/data/npg_api/npg/run/1.xml},
  $base_url.q{/run/6} => q{<?xml version="1.0" encoding="utf-8"?><run id_run="6" is_paired="" id_run_pair=""></run>},
  $base_url.q{/run/7} => q{<?xml version="1.0" encoding="utf-8"?><run id_run="7" is_paired="" id_run_pair=""></run>},
  $base_url.q{/run/9} => q{<?xml version="1.0" encoding="utf-8"?><run id_run="9" is_paired="1" id_run_pair="10"></run>},
  $base_url . q{/run/13} => q{<?xml version="1.0" encoding="utf-8"?><run id_run="9" is_paired="0" id_run_pair=""></run>},
  $base_url . q{/run/18} => q{<?xml version="1.0" encoding="utf-8"?><run id_run="18" is_paired="0" id_run_pair=""></run>},
          },
        });
  my $util = npg::api::util->new({
          useragent => $ua,
         });
  my $i_u  = npg::api::instrument_utilisation->new({
         util   => $util,
         yesterday_datetime_object => test_required_yesterday(),
         two_days_ago_datetime_object => test_required_two_days_ago(),
         three_days_ago_datetime_object => test_required_three_days_ago(),
        });

  isa_ok($i_u,'npg::api::instrument_utilisation', '$i_u');

  $i_u->_type( q{ga2} );
  my $test_deeply = [
    { id_run =>  1, start => '2007-06-05 10:04:23', end => '2009-01-29 14:09:31', id_instrument => 3},
    { id_run =>  5, start => '2007-06-05 12:31:44', end => '2007-06-05 12:32:28', id_instrument => 3},
    { id_run => 95, start => '2007-06-05 10:04:23', end => '2007-06-05 11:16:55', id_instrument => 4},
  ];

  my $runs = $i_u->recent_running_runs();

  is_deeply($runs, $test_deeply, 'returned data structure is correct');
  is($i_u->recent_running_runs(), $runs, '$i_u->recent_running_runs() cached ok');

  my $instruments = test_instrument_stack();

  $i_u->instruments($instruments);
  $i_u->total_insts(6);
  $i_u->prod_insts(4);
  $i_u->official_insts(5);

  my $dt = test_required_yesterday();
  my $yesterday = $dt->ymd() . q{ } . $dt->hms;
  my $two_days_ago = test_required_two_days_ago();
  my $two_days_ago_time = $two_days_ago->ymd() . q{ 10:13:12};
  $runs->[0]->{end} = $yesterday;
  push @{$runs}, { id_run => 3, start => $yesterday, end => $yesterday, id_instrument => 1};
  push @{$runs}, { id_run => 4, start => $yesterday, end => $yesterday, id_instrument => 5};
  push @{$runs}, { id_run => 6, start => '2007-06-05 12:31:44', end => $two_days_ago_time, id_instrument => 6}; # 42 %
  push @{$runs}, { id_run => 7, start => '2009-01-30 00:00:00', end => '2009-02-01 15:30:00', id_instrument => 7}; # 100% after join with id_run 16
  push @{$runs}, { id_run => 8, start => $yesterday, end => $yesterday, id_instrument => 3};
  push @{$runs}, { id_run => 9, start => '2009-01-31 00:00:00', end => '2009-02-02 08:00:00', id_instrument => 4}; # 100% after join with id_run 10
  push @{$runs}, { id_run => 10, start => '2009-02-03 00:00:01', end => '2009-02-04 00:00:15', id_instrument => 4};
  push @{$runs}, { id_run => 11, start => '2009-02-01 00:00:00', end => '2009-02-02 15:00:00', id_instrument => 8}; # 100% after extension
  push @{$runs}, { id_run => 12, start => '2009-01-31 00:00:00', end => '2009-02-01 15:00:00', id_instrument => 6};
  push @{$runs}, { id_run => 13, start => '2009-02-01 16:00:00', end => '2009-02-04 00:00:15', id_instrument => 3}; # 100%
  push @{$runs}, { id_run => 14, start => '2009-12-25 00:00:00', end => '2010-01-01 00:00:00', id_instrument => 3};
  push @{$runs}, { id_run => 15, start => '2009-02-01 16:00:00', end => '2009-02-04 00:00:15', id_instrument => 6}; # 100%
  push @{$runs}, { id_run => 16, start => $two_days_ago_time, end => $yesterday, id_instrument => 7};
  push @{$runs}, { id_run => 17, start => '2009-01-31 00:00:00', end => $two_days_ago_time, id_instrument => 9}; # 42%
  push @{$runs}, { id_run => 18, start => '2009-01-30 10:00:00', end => '2009-02-01 10:00:00', id_instrument => 10};
  push @{$runs}, { id_run => 19, start => '2009-02-03 10:00:00', end => '2009-02-04 00:00:00', id_instrument => 10};
  
  lives_ok { $i_u->two_days_ago_utilisation_in_seconds() } q{no croak working out utilisation for yesterday};
  is($i_u->perc_utilisation_total_insts(), '83.33', 'perc_utilisation_total_insts calculated ok');
  is($i_u->perc_utilisation_official_insts(), '100.00', 'perc_utilisation_official_insts calculated ok');
  is($i_u->perc_utilisation_prod_insts(), '75.00', 'perc_utilisation_prod_insts calculated ok');

  my $start_of_yesterday = $i_u->beginning_of_yesterday_dt_object();
  is($start_of_yesterday->ymd() . q{T} . $start_of_yesterday->hms(), '2009-02-03T00:00:00', 'start of yesterday dt object is as expected');
  is($i_u->beginning_of_yesterday_dt_object(), $start_of_yesterday, 'cache ok for $i_u->beginning_of_yesterday_dt_object()');
  my $end_of_yesterday = $i_u->end_of_yesterday_dt_object();
  is($end_of_yesterday->ymd() . q{T} . $end_of_yesterday->hms(), '2009-02-03T23:59:59', 'end of yesterday dt object is as expected');
  is($i_u->end_of_yesterday_dt_object(), $end_of_yesterday, 'cache ok for $i_u->end_of_yesterday_dt_object()');
  my $start_of_two_days_ago = $i_u->beginning_of_two_days_ago_dt_object();
  is($start_of_two_days_ago->ymd() . q{T} . $start_of_two_days_ago->hms(), '2009-02-02T00:00:00', 'start of two_days_ago dt object is as expected');
  is($i_u->beginning_of_two_days_ago_dt_object(), $start_of_two_days_ago, 'cache ok for $i_u->beginning_of_two_days_ago_dt_object()');
  my $end_of_two_days_ago = $i_u->end_of_two_days_ago_dt_object();
  is($end_of_two_days_ago->ymd() . q{T} . $end_of_two_days_ago->hms(), '2009-02-02T23:59:59', 'end of two_days_ago dt object is as expected');
  is($i_u->end_of_two_days_ago_dt_object(), $end_of_two_days_ago, 'cache ok for $i_u->end_of_two_days_ago_dt_object()');
}

{
  my $ua   = t::useragent->new({
        is_success => 1,
        mock => {
    $base_url . q{/instument.xml} => q{t/data/npg_api/npg/instrument_designation_list.xml},
    $base_url . q{/instrument} => q{t/data/npg_api/npg/instrument_designation_list.xml},
    $base_url . q{/run/recent/running/runs.xml} => q{t/data/rendered/run/recent/running/runs_4000_days.xml},
    $base_url . q{/instrument_status/up/down.xml} => q{t/data/rendered/instrument_status/list_up_down_xml.xml},
          },
        });
  my $util = npg::api::util->new({
          useragent => $ua,
         });
  my $i_u  = npg::api::instrument_utilisation->new({
         util   => $util,
        });

  isa_ok($i_u,'npg::api::instrument_utilisation', '$i_u');

  $i_u->{_type} = q{ga2};

  my $instruments;
  lives_ok { $instruments = $i_u->api_instruments(); } q{no croak on obtaining api_instruments};
  is($i_u->api_instruments(), $instruments, 'api_instruments cached ok');

  my $miseq_insts;
  lives_ok { $miseq_insts = $i_u->_current_instruments( q{miseq} ); } q{no croak on obtaining current miseq instruments};
  is($i_u->total_insts(), 9, '9 of the 13 instruments are current MISeq');
  is(scalar@{$miseq_insts}, 9, '9 instruments in returned list');

  my $ga2_insts;
  lives_ok { $ga2_insts = $i_u->_current_instruments( q{ga2} ); } q{no croak on obtaining current ga2 instruments};
  is($i_u->total_insts(), 9, '9 of the 13 instruments are current GA2');
  is(scalar@{$ga2_insts}, 9, '9 instruments in returned list');

  my ($il10, $il11,$il12, $il13);
  foreach my $i (@{$ga2_insts}) {
    if ($i->name() eq 'IL10') { $il10++; }
    if ($i->name() eq 'IL11') { $il11++; }
    if ($i->name() eq 'IL12') { $il12++; }
    if ($i->name() eq 'IL13') { $il13++; }
  }
  ok(!$il10, 'IL10 has been discarded');
  ok(!$il11, 'IL11 has been discarded');
  ok(!$il12, 'IL12 has been discarded');
  ok(!$il13, 'IL13 has been discarded');

  lives_ok { $i_u->determine_instrument_designations($ga2_insts); } q{no croak on $i_u->determine_instrument_designations($ga2_insts)};

  my $test_ydt = $i_u->yesterday_datetime_object();
  isa_ok($test_ydt, 'DateTime', '$test_ydt');
  is($i_u->yesterday_datetime_object(), $test_ydt, 'cached ok');

  my $test_2dadt = $i_u->two_days_ago_datetime_object();
  isa_ok($test_2dadt, 'DateTime', '$test_2dadt');
  is($i_u->two_days_ago_datetime_object(), $test_2dadt, 'cached ok');

  my $test_3dadt = $i_u->three_days_ago_datetime_object();
  isa_ok($test_3dadt, 'DateTime', '$test_3dadt');
  is($i_u->three_days_ago_datetime_object(), $test_3dadt, 'cached ok');

  $i_u->{yesterday_datetime_object} = test_required_yesterday();
  $i_u->{beginning_of_yesterday_dt_object} = undef;
  $i_u->{end_of_yesterday_dt_object} = undef;
  $i_u->{two_days_ago_datetime_object} = test_required_two_days_ago();
  $i_u->{beginning_of_two_days_ago_dt_object} = undef;
  $i_u->{end_of_two_days_ago_dt_object} = undef;
  $i_u->{three_days_ago_datetime_object} = test_required_three_days_ago();
  $i_u->{beginning_of_three_days_ago_dt_object} = undef;
  $i_u->{end_of_three_days_ago_dt_object} = undef;

  is($i_u->two_pm_cutoff(1)->ymd() . q{T}. $i_u->two_pm_cutoff(1)->hms(), q{2009-02-03T14:00:00}, '$i_u->two_pm_cutoff(1) - yesterday');
  is($i_u->two_pm_cutoff(2)->ymd() . q{T}. $i_u->two_pm_cutoff(2)->hms(), q{2009-02-02T14:00:00}, '$i_u->two_pm_cutoff(2) - two days ago');
  is($i_u->two_pm_cutoff(3)->ymd() . q{T}. $i_u->two_pm_cutoff(3)->hms(), q{2009-02-01T14:00:00}, '$i_u->two_pm_cutoff(3) - three days ago');

  my $seconds_per_instrument;
  lives_ok { $seconds_per_instrument = $i_u->two_days_ago_uptime_in_seconds(); }  q{no croak on $i_u->two_days_ago_uptime_in_seconds()};
  my $test_deeply = {
    IL10 => { seconds => 86400 },
    IL2 => { seconds => 86400 },
    IL3 => { seconds => 0 },
    IL4 => { seconds => 0 },
    IL6 => { seconds => 0 },
    IL7 => { seconds => 86400 },
    IL8 => { seconds => 86400 },
    IL9 => { seconds => 86400 },
  };
  is_deeply($seconds_per_instrument, $test_deeply, 'seconds uptime is ok');

  $test_deeply = {
    IL10 => { seconds => 86400, percentage => '100.00' },
    IL2 => { seconds => 86400, percentage => '100.00' },
    IL3 => { seconds => 0, percentage => '0.00' },
    IL4 => { seconds => 0, percentage => '0.00' },
    IL6 => { seconds => 0, percentage => '0.00' },
    IL7 => { seconds => 86400, percentage => '100.00' },
    IL8 => { seconds => 86400, percentage => '100.00' },
    IL9 => { seconds => 86400, percentage => '100.00' },
  };
  my $two_days_ago_uptime;
  lives_ok { $two_days_ago_uptime = $i_u->two_days_ago_uptime(); } q{no croak on $i_u->two_days_ago_uptime()};
  is_deeply($two_days_ago_uptime, $test_deeply, 'two_days_ago uptime is ok');
  
  lives_ok { $i_u->percentage_uptimes_of_all_instruments(); } q{no croak on $i_u->percentage_uptimes_of_all_instruments()};
  is($i_u->perc_uptime_total_insts(), '44.44', '$i_u->perc_uptime_total_insts() ok');
  is($i_u->perc_uptime_official_insts(), '66.67', '$i_u->perc_uptime_official_insts() ok');
  is($i_u->perc_uptime_prod_insts(), '50.00', '$i_u->perc_uptime_prod_insts() ok');
}

{
  my $uptimes_data = [
    {
     name => 'IL1',
     statuses => [{ date => '2007-01-01 00:00:00', description => 'up' },{ date => '2009-02-02 09:15:32', description => 'down' },{ date => '2009-02-02 13:30:00', description => 'up' },{ date => '2009-02-03 10:00:00', description => 'down' }],
    },
    {
     name => 'IL2',
     statuses => [{ date => '2007-01-01 00:00:00', description => 'up' },{ date => '2009-02-02 09:15:32', description => 'down' },{ date => '2009-02-03 09:30:00', description => 'up' },{ date => '2009-02-03 10:00:00', description => 'down' }],
    },
    {
     name => 'IL3',
     statuses => [{ date => '2007-01-01 00:00:00', description => 'down' },{ date => '2009-02-02 09:15:32', description => 'up' },{ date => '2009-02-03 09:30:00', description => 'down' },{ date => '2009-02-03 10:00:00', description => 'up' }],
    },
    {
     name => 'IL4',
     statuses => [{ date => '2007-01-01 00:00:00', description => 'down' },{ date => '2009-02-02 09:15:32', description => 'up' },{ date => '2009-02-02 09:30:00', description => 'up' },{ date => '2009-02-03 10:00:00', description => 'down' }],
    },
    {
     name => 'IL5',
     statuses => [{ date => '2007-01-01 00:00:00', description => 'down' },{ date => '2009-02-02 09:15:32', description => 'down' },{ date => '2009-02-02 09:30:00', description => 'down' },{ date => '2009-02-03 10:00:00', description => 'down' }],
    },
    {
     name => 'IL6',
     statuses => [{ date => '2007-01-01 00:00:00', description => 'up' },{ date => '2009-02-02 09:15:32', description => 'up' },{ date => '2009-02-02 09:30:00', description => 'up' },{ date => '2009-02-03 10:00:00', description => 'up' }],
    },
    {
     name => 'IL7',
     statuses => [{ date => '2007-01-01 00:00:00', description => 'up' },{ date => '2009-02-03 10:00:00', description => 'up' }],
    },
    {
     name => 'IL8',
     statuses => [{ date => '2007-01-01 00:00:00', description => 'up' }],
    },
    {
     name => 'IL9',
     statuses => [{ date => '2007-01-01 00:00:00', description => 'down' }],
    },
  ];
  my $ua   = t::useragent->new({
        is_success => 1,
        });
  my $util = npg::api::util->new({
          useragent => $ua,
         });
         
  my $instrument_status = npg::api::instrument_status->new({util => $util, uptimes => $uptimes_data});

  my $i_u  = npg::api::instrument_utilisation->new({
         util   => $util,
         instrument_status_object => $instrument_status,
         yesterday_datetime_object => test_required_yesterday(),
         two_days_ago_datetime_object => test_required_two_days_ago(),
         three_days_ago_datetime_object => test_required_three_days_ago(),
         instruments => test_instrument_stack(),
         total_insts => 6,
         prod_insts => 4,
         official_insts => 5,
        });

  isa_ok($i_u,'npg::api::instrument_utilisation', '$i_u');
  $i_u->_type( q{ga2} );
  is($i_u->instrument_status_object(), $instrument_status, 'primed instrument_status into cache ok');
  is($i_u->instrument_status_object()->uptimes(), $uptimes_data, 'primed uptime data into cache ok');

  my $uptime;
  lives_ok { $uptime = $i_u->two_days_ago_uptime(); } q{no croak using primed uptime_data};
  is(scalar keys%{$uptime}, 9, '9 instruments');

  my $test_deeply = {
    IL1 => { percentage => '82.33', seconds => 71131, },
    IL2 => { percentage => '38.58', seconds => 33332, },
    IL3 => { percentage => '61.42', seconds => 53067, },
    IL4 => { percentage => '1.00', seconds => 868, },
    IL5 => { percentage => '0.00', seconds => 0, },
    IL6 => { percentage => '81.25', seconds => 70201, },
    IL7 => { percentage => '100.00', seconds => 86400, },
    IL8 => { percentage => '100.00', seconds => 86400, },
    IL9 => { percentage => '0.00', seconds => 0, },
  };
  is_deeply($uptime, $test_deeply, 'correct data structure for seconds uptime returned');
  is($i_u->two_days_ago_uptime(), $uptime, 'cache ok for $i_u->two_days_ago_uptime()');

  lives_ok { $i_u->percentage_uptimes_of_all_instruments(); } q{no croak on $i_u->percentage_uptimes_of_all_instruments()};
  is($i_u->perc_uptime_total_insts(), '44.10', '$i_u->perc_uptime_total_insts() ok');
  is($i_u->perc_uptime_official_insts(), '52.92', '$i_u->perc_uptime_official_insts() ok');
  is($i_u->perc_uptime_prod_insts(), '65.89', '$i_u->perc_uptime_prod_insts() ok');
  
  lives_ok { $i_u->insert_date_for_record(); } q{no croak on $i_u->insert_date_for_record()};
  is($i_u->date(), '2009-02-02 00:00:00', '$i_u->date() is correct');
}

{
  my $ua   = t::useragent->new({
        is_success => 1,
        mock => {
    $base_url . q{/instument.xml} => q{t/data/npg_api/npg/instrument_designation_list.xml},
    $base_url . q{/instrument} => q{t/data/npg_api/npg/instrument_designation_list.xml},
    $base_url . q{/run/recent/running/runs.xml} => q{t/data/rendered/run/recent/running/runs_4000_days.xml},
    $base_url . q{/instrument_status/up/down.xml} => q{t/data/npg_api/npg/instrument_status/list_up_down_xml.xml},
    $base_url . q{/instrument_utilisation.xml} => q{t/data/npg_api/npg/instrument_utilisation/20090202.xml},
          },
        });
  my $util = npg::api::util->new({
          useragent => $ua,
         });
  my $i_u  = npg::api::instrument_utilisation->new({
         util   => $util,
         yesterday_datetime_object => test_required_yesterday(),
         two_days_ago_datetime_object => test_required_two_days_ago(),
         three_days_ago_datetime_object => test_required_three_days_ago(),
        });
  isa_ok($i_u,'npg::api::instrument_utilisation', '$i_u');
  $i_u->_type( q{ga2} );
  
  lives_ok { $i_u->calculate_ga2_values(); } q{no croak running the whole lot via $i_u->calculate_ga2_values()};
  is( $i_u->id_instrument_utilisation(), '1', '$i_u->id_instrument_utilisation() is correct' );
  is( $i_u->date(), '2009-02-02 00:00:00', '$i_u->date() is correct' );
  is( $i_u->total_insts(), '9', '$i_u->total_insts() is correct' );
  is( $i_u->perc_utilisation_total_insts(), '0.00', '$i_u->perc_utilisation_total_insts() is correct' );
  is( $i_u->perc_uptime_total_insts(), '44.44', '$i_u->perc_uptime_total_insts() is correct' );
  is( $i_u->official_insts(), '6', '$i_u->official_insts() is correct' );
  is( $i_u->perc_utilisation_official_insts(), '0.00', '$i_u->perc_utilisation_official_insts() is correct' );
  is( $i_u->perc_uptime_official_insts(), '50.00', '$i_u->perc_uptime_official_insts() is correct' );
  is( $i_u->prod_insts(), '8', '$i_u->prod_insts() is correct' );
  is( $i_u->perc_utilisation_prod_insts(), '0.00', '$i_u->perc_utilisation_prod_insts() is correct' );
  is( $i_u->perc_uptime_prod_insts(), '50.00', '$i_u->perc_uptime_prod_insts() is correct' );
  is( $i_u->id_instrument_format(), 4, '$i_u->id_instrument_format() is correct' );
  $i_u->id_instrument_utilisation( undef );
  lives_ok { $i_u->create( q{xml} ); } q{no croak running create};

  lives_ok { $i_u->calculate_miseq_values( { no_create => 1 } ); } q{no croak running the whole lot via $i_u->calculate_miseq_values()};
  lives_ok { $i_u->calculate_hiseq_values( { no_create => 1 } ); } q{no croak running the whole lot via $i_u->calculate_hiseq_values()};

  is( $i_u->id_instrument_utilisation(), undef, '$i_u->id_instrument_utilisation() is correct' );
  is( $i_u->date(), '2009-02-02 00:00:00', '$i_u->date() is correct' );
  is( $i_u->total_insts(), 4, '$i_u->total_insts() is correct' );
  is( $i_u->perc_utilisation_total_insts(), '0.00', '$i_u->perc_utilisation_total_insts() is correct' );
  is( $i_u->perc_uptime_total_insts(), '75.00', '$i_u->perc_uptime_total_insts() is correct' );
  is( $i_u->official_insts(), 2, '$i_u->official_insts() is correct' );
  is( $i_u->perc_utilisation_official_insts(), '0.00', '$i_u->perc_utilisation_official_insts() is correct' );
  is( $i_u->perc_uptime_official_insts(), '150.00', '$i_u->perc_uptime_official_insts() is correct' );
  is( $i_u->prod_insts(), 4, '$i_u->prod_insts() is correct' );
  is( $i_u->perc_utilisation_prod_insts(), '0.00', '$i_u->perc_utilisation_prod_insts() is correct' );
  is( $i_u->perc_uptime_prod_insts(), '75.00', '$i_u->perc_uptime_prod_insts() is correct' );
  is( $i_u->id_instrument_format(), 10, '$i_u->id_instrument_format() is correct' );
  
}

{
  my $ua   = t::useragent->new({
        is_success => 1,
        mock => {
    $base_url . q{/instument.xml} => q{t/data/npg_api/npg/instrument_designation_list.xml},
    $base_url . q{/instrument} => q{t/data/npg_api/npg/instrument_designation_list.xml},
    $base_url . q{/recent/running/runs.xml} => q{t/data/rendered/run/recent/running/runs_4000_days.xml},
    $base_url . q{/instrument_status/up/down.xml} => q{t/data/rendered/instrument_status/list_up_down_xml.xml},
          },
        });
  my $util = npg::api::util->new({
          useragent => $ua,
         });
  my $i_u  = npg::api::instrument_utilisation->new({
         util   => $util,
         yesterday_datetime_object => test_required_yesterday(),
         two_days_ago_datetime_object => test_required_two_days_ago(),
         three_days_ago_datetime_object => test_required_three_days_ago(),
        });
  isa_ok($i_u,'npg::api::instrument_utilisation', '$i_u');
  
  throws_ok { $i_u->calculate_ga2_values(); } qr{Unable[ ]to[ ]calculate[ ]ga2[ ]values}, q{croaked on running $i_u->calculate_ga2_values()};
}
1;
