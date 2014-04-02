use strict;
use warnings;
use Test::More tests => 13;
use t::useragent;
use npg::api::util;

use_ok('npg::api::instrument_status');
my $base_url = $npg::api::util::LIVE_BASE_URI;
{
  my $i_s  = npg::api::instrument_status->new();
  isa_ok($i_s,'npg::api::instrument_status', '$i_s');
}

{
  my $ua   = t::useragent->new({
        is_success => 1,
        mock => {
           $base_url . q{/instrument_status/up/down.xml} => q{t/data/rendered/instrument_status/list_up_down_xml.xml},
          },
        });

  my $i_s  = npg::api::instrument_status->new({
         util   => npg::api::util->new({useragent => $ua}),
        });
  isa_ok($i_s,'npg::api::instrument_status', '$i_s');
  my @fields = $i_s->fields();
  is($fields[0], 'id_instrument_status', '$fields[0] is id_instrument_status');
  is($fields[1], 'id_instrument', '$fields[1] is id_instrument');
  is($fields[2], 'date', '$fields[2] is date');
  is($fields[3], 'id_instrument_status_dict', '$fields[3] is id_instrument_status_dict');
  is($fields[4], 'id_user', '$fields[4] is id_user');
  is($fields[5], 'iscurrent', '$fields[5] is iscurrent');
  is($fields[6], 'description', '$fields[6] is description');
  is($fields[7], 'comment', '$fields[7] is comment');
  my $test_deeply = [
    { name => 'IL10', statuses => [{date=>'2007-09-20 15:02:53', description=>'up'},{date=>"2009-02-03 12:25:32", description=>"down"}], },
    { name => 'IL2',  statuses => [{date=>"2007-09-19 13:09:42", description=>"up"},{date=>"2009-02-03 12:25:32", description=>"down"}], },
    { name => 'IL3',  statuses => [{date=>"2007-09-19 13:09:42", description=>"up"},{date=>"2007-10-02 11:02:52", description=>"down"}], },
    { name => 'IL4',  statuses => [{date=>"2007-09-19 13:09:41", description=>"up"},{date=>"2007-09-19 13:10:53", description=>"down"}], },
    { name => 'IL6',  statuses => [{date=>"2007-09-19 13:09:41", description=>"up"},{date=>"2007-10-02 11:02:52", description=>"down"}], },
    { name => 'IL7',  statuses => [{date=>"2007-09-19 13:09:41", description=>"up"},{date=>"2007-09-20 15:00:53", description=>"down"},{date=>"2007-10-02 11:02:52", description=>"up"},{date=>"2009-02-03 12:25:32", description=>"down"}], },
    { name => 'IL8',  statuses => [{date=>"2007-10-02 11:02:52", description=>"up"},{date=>"2009-02-03 12:25:32", description=>"down"}], },
    { name => 'IL9',  statuses => [{date=>"2007-09-19 13:09:41", description=>"up"},{date=>"2007-09-20 15:02:52", description=>"down"},{date=>"2007-10-02 11:02:52", description=>"up"},{date=>"2009-02-03 12:25:32", description=>"down"}], },
  ];
  my $instruments = $i_s->uptimes();
  is_deeply($instruments, $test_deeply, 'correct data structure obtained from $i_s->uptimes()');
  is($i_s->uptimes(), $instruments, 'caching of $i_u->uptimes() is ok');
}

1
