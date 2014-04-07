use strict;
use warnings;
use Test::More tests => 30;
use Test::Exception;
use Test::Deep;
use File::Temp qw/ tempdir /;
use File::Spec::Functions qw(catfile);
use File::Path qw(make_path );
use HTTP::Request::Common;
use Test::MockObject;

use st::api::batch;
use npg::api::util;
use st::api::sample;

use t::useragent;
my $lims_url = q[http://psd-support.internal.sanger.ac.uk:6600];
my $ua = t::useragent->new({
                         is_success => 1,
                         mock       => {
   $lims_url.q{/batches/1027}  => q{t/data/npg_api/st/batches/1027.xml},
   $lims_url.q{/batches/1826}  => q{t/data/npg_api/st/batches/1826.xml},
   $lims_url.q{/samples/10014} => q{t/data/npg_api/st/samples/10014.xml},
                                       },   
                          });

use_ok('npg::api::request');

my $base_url = $npg::api::util::LIVE_BASE_URI;
my $VAR_NAME = q[];
my $TEST_CACHE = q[t/data/npg_api];

{
  my $r = npg::api::request->new();
  isa_ok($r, 'npg::api::request');
  $VAR_NAME = $r->cache_dir_var_name;
}

{
  is (npg::api::request->cache_dir_var_name, q[NPG_WEBSERVICE_CACHE_DIR], 'class attr for var name');
  is (npg::api::request->new()->cache_dir_var_name, q[NPG_WEBSERVICE_CACHE_DIR], 'class attr for var name works for an instance as well');
  is (npg::api::request->new()->cache_dir_var_name, q[NPG_WEBSERVICE_CACHE_DIR], 'class attr for var name works for an instance as well');
}

{
  my $r = npg::api::request->new();
  throws_ok { $r->make() } qr/Uri is not defined/, 'error if no uri given';
  throws_ok { $r->make(q[]) } qr/Uri is not defined/, 'error if an empty uri given';
 
  local $ENV{$VAR_NAME} = q[/dome/non-existing];
  throws_ok { $r->make(q[dodo], q[GET]) } qr/Cache directory \/dome\/non-existing does not exist/, 'error when a cache directory does not exist';

  local $ENV{$VAR_NAME} = q[Changes];
  throws_ok { $r->make(q[dodo], q[GET]) } qr/is not a directory/, 'error when a cache directory is not a directory';
}

{
  local $ENV{$VAR_NAME} = q[t];
  my $r = npg::api::request->new();

  is( $r->_create_path($base_url.q{/run/1234.xml}), 
                       q{t/npg/run/1234.xml}, q{npg path generated ok} );
  is( $r->_create_path($lims_url.q{/batches/6935.xml}), 
                       q{t/st/batches/6935.xml}, q{st path created ok});
  is( $r->_create_path(q{http://news.bbc.co.uk/sport1/hi/football/world_cup_2010/matches/match_01}), 
     q{t/ext/sport1/hi/football/world_cup_2010/matches/match_01},
     q{external path generated ok} );
}

{
  my $r = npg::api::request->new();
  my $req = GET q[dodo];
  $r->_personalise_request($req);
  is ($req->header(q[X-username]), getlogin, 'username set in the request header');
}

{
    my $util = npg::api::util->new({useragent => $ua, max_retries => 1,});
    my $sample_id = 10014;
    ok (-e catfile($TEST_CACHE, q[st], q[samples], $sample_id . q[.xml]), 'test prerequisite OK');
    is ( st::api::sample->new({id => $sample_id, util => npg::api::util->new({useragent => $ua,}), })->name, q[104A_Sc_YPS128], 'sample fetched,  name correct');

    my $dir = tempdir( CLEANUP => 1 );
    local $ENV{$VAR_NAME} = $dir;
    throws_ok { st::api::sample->new({id => $sample_id,})->name } qr/is not in the cache/, 'error when fetching from a cache a resource that is not there';
}

{
    my $util = npg::api::util->new({useragent => $ua, max_retries => 1,});
    my $batch_id = 1027;
    my $url = catfile(q[st], q[batches], $batch_id . q[.xml]);
    ok (-e catfile($TEST_CACHE, $url), 'test prerequisite OK');
    lives_ok {st::api::batch->new({id => $batch_id, util => $util,})->read()} 'batch retrieved';

    my $dir = tempdir( CLEANUP => 1 );
    local $ENV{$VAR_NAME} = $dir;
    throws_ok { st::api::batch->new({id => $batch_id, util => $util,})->read()}
      qr/is not in the cache/, 'error when a resource is not in cache';

    local $ENV{npg::api::request->save2cache_dir_var_name} = 1;
    lives_ok { st::api::batch->new({util => $util, id => $batch_id})->read() }
      'call to request and save the resource lives';
    ok (-e catfile($dir, $url), 'batch xml saved to cache');

    $batch_id = 1826;
    $url = catfile(q[st], q[batches], $batch_id . q[.xml]);
    ok (-e catfile($TEST_CACHE, $url), 'test prerequisite OK');
    lives_ok { st::api::batch->new({util => $util, id => $batch_id, })->read() } 'call to save a second batch lives';
    ok (-e catfile($dir, $url), 'second batch xml saved to cache');
}

{
  my $batch_id = 3022;
  my $original = catfile($TEST_CACHE, q[st], q[batches], $batch_id . q[.xml]);
  ok (-e $original, 'test prerequisite OK'); 
  my $batch1 = st::api::batch->new({id => $batch_id,});
  
  my $cache = tempdir( CLEANUP => 1 );
  local $ENV{$VAR_NAME} = $cache;
  make_path  catfile($cache, q[st], q[batches]);
  my $copy = catfile($cache, q[st], q[batches], $batch_id . q[.xml]);
  `cp $original $copy`;
  ok (-e $copy, 'test prerequisite OK');
  my $batch2 = st::api::batch->new({id => $batch_id,});
  cmp_deeply ($batch1, $batch2, 'the same object returned from cache and test repository');
}


{
  my $content = q[Run 2888 tagged];

  my $mockUA = Test::MockObject->new();
  $mockUA->fake_new(q{LWP::UserAgent});

  my $fake_response = HTTP::Response->new(200, '200 Ok', undef, "$content");
  $mockUA->set_always('request', $fake_response);
  $mockUA->set_always('timeout', 60);
  $mockUA->set_always('agent', q[npg::api::request]);
  $mockUA->set_always('env_proxy', q[]);
  my $returned;
  lives_ok {$returned = npg::api::request->new()->make($base_url.q[/run/4913], q[POST])} 'post request lives';
  is ($returned, $content, 'correct response returned');

  local $ENV{$VAR_NAME} = q[t];
  throws_ok {npg::api::request->new()->make($base_url.q[/run/4913], q[POST])}
    qr/POST requests cannot use cache:/, 'post request croaks if cache is set';
}

1;
