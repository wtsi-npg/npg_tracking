use strict;
use warnings;

use File::Temp qw(tempdir);
use JSON;
use Log::Log4perl qw[:levels];
use Test::HTTP::Server;
use Test::More;
use Test::Exception;
use URI;

use_ok('npg_tracking::heron::upload::run');
use_ok('npg_tracking::heron::upload::metadata_client');

my $logfile = join q[/], tempdir(CLEANUP => 1), 'logfile';
note "Log file: $logfile";
Log::Log4perl->easy_init({layout => '%d %-5p %c - %m%n',
                          level  => $DEBUG,
                          file   => $logfile,
                          utf8   => 1});

my $request_success = 1;
sub Test::HTTP::Server::Request::api {
  if ($request_success) {
    # Example of a success response
    return encode_json({errors   => 0,
                        warnings => 0,
                        messages => [],
                        new      => [
                            ['object_type1', 'object_uuid1', 'object_id1'],
                            ['object_type1', 'object_uuid2', 'object_id2'],
                            ['object_type1', 'object_uuid3', 'object_id3'],
                        ],
                        updated  => [],
                        ignored  => [],

                        success  => 1});
  }

  # Example of a failure response
  return encode_json({errors   => 1,
                      warnings => 0,
                      messages => [],
                      new      => [],
                      updated  => [],
                      ignored  => [],

                      success  => 0});
}

my $library_name = 'test_library_name';
my $make  = 'ILLUMINA';
my $model = 'NovaSeq';
my @instrument_args = (instrument_make  => $make,
                       instrument_model => $model);

# We can make valid runs
ok(npg_tracking::heron::upload::run->new(name             => 'run1',
                                         instrument_make  => 'ILLUMINA',
                                         instrument_model => 'SomeModel'),
   'ILLUMINA make is OK');
ok(npg_tracking::heron::upload::run->new(name             => 'SANG-run1',
                                         instrument_make  => 'OXFORD_NANOPORE',
                                         instrument_model => 'SomeModel'),
   'OXFORD_NANOPORE make is OK');
ok(npg_tracking::heron::upload::run->new(name             => 'SANG-run1',
                                         instrument_make  => 'PACIFIC_BIOSCIENCES',
                                         instrument_model => 'SomeModel'),
   'PACIFIC_BIOSCIENCES make is OK');

like(npg_tracking::heron::upload::run->new(name             => 'SANG-run1',
                                           instrument_make  => 'ILLUMINA',
                                           instrument_model => 'SomeModel')->name,
     qr{SANG-.*}, 'Run name has correct form');

dies_ok {
  npg_tracking::heron::upload::run->new(name             => 'SANG-run1',
                                        instrument_make  => 'invalid_make',
                                        instrument_model => 'SomeModel');
} 'run will not accept an invalid make';

my @runs = (npg_tracking::heron::upload::run->new(name => 'SANG-run1', @instrument_args),
            npg_tracking::heron::upload::run->new(name => 'SANG-run2', @instrument_args),
            npg_tracking::heron::upload::run->new(name => 'SANG-run3', @instrument_args));

my $server = Test::HTTP::Server->new;
my $server_uri = URI->new($server->uri);
my $client = npg_tracking::heron::upload::metadata_client->new
    (username  => 'test_username',
     token     => 'test_token',
     api_uri   => $server_uri);

is($client->api_uri, $server_uri, 'has expected URI') or diag explain
    "Expected $server_uri, but got " . $client->api_uri;

my $add_success_response = {
    errors   => 0,
    warnings => 0,
    messages => [],
    new      => [
          ['object_type1', 'object_uuid1', 'object_id1'],
          ['object_type1', 'object_uuid2', 'object_id2'],
          ['object_type1', 'object_uuid3', 'object_id3'],
    ],
    updated  => [],
    ignored  => [],

    success  => 1
};

# We can send POST requests and accept a success response
my $response = $client->send_metadata($library_name, @runs);
ok($response, 'Send response successful');
is_deeply($response, $add_success_response) or
    diag explain $response;

# We error on  a failure response
undef $server;
$request_success = 0;
$server = Test::HTTP::Server->new;

dies_ok {
  $response = $client->send_metadata($library_name, @runs);
} 'Sending metadata dies on error response';

done_testing();
