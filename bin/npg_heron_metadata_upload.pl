#!/usr/bin/env perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib ( -d "$Bin/../lib/perl5" ? "$Bin/../lib/perl5" : "$Bin/../lib" );

use Carp;
use Getopt::Long;
use List::MoreUtils qw[uniq];
use Log::Log4perl qw(:levels);
use URI;
use Pod::Usage;
use Try::Tiny;

use WTSI::DNAP::Warehouse::Schema;

use npg_tracking::Schema;
use npg_tracking::heron::upload::run;
use npg_tracking::heron::upload::metadata_client;

our $VERSION = '0';

my $debug;
my $dry_run;
my @id_run;
my $instrument_make;
my $instrument_model;
my $library_name;
my $token;
my $url;
my $username;
my $verbose;

GetOptions('debug'                               => \$debug,
           'dry_run|dry-run'                     => \$dry_run,
           'id_run|id-run=@'                     => \@id_run,
           'instrument_make|instrument-make=s'   => \$instrument_make,
           'instrument_model|instrument-model=s' => \$instrument_model,
           'library_name|library-name=s'         => \$library_name,
           'token=s'                             => \$token,
           'url=s'                               => \$url,
           'username=s'                          => \$username,
           'verbose'                             => \$verbose);

my $level = $debug ? $DEBUG : $verbose ? $INFO : $WARN;
Log::Log4perl->easy_init({layout => '%d %-5p %c - %m%n',
                          level  => $level,
                          utf8   => 1});

my $log = Log::Log4perl->get_logger('main');

if (not @id_run) {
  pod2usage(-msg => 'At least one --id-run argument is required',  -exitval => 2);
}
if (not $url) {
  pod2usage(-msg => 'A --url argument is required',  -exitval => 2);
}
if (not $username) {
  pod2usage(-msg => 'A --username argument is required',  -exitval => 2);
}
if (not $token) {
  pod2usage(-msg => 'A --token argument is required',  -exitval => 2);
}

my $warehouse_db = WTSI::DNAP::Warehouse::Schema->connect();
my $tracking_db = npg_tracking::Schema->connect();

my $client = npg_tracking::heron::upload::metadata_client->new
    (api_uri   => URI->new($url),
     token     => $token,
     username  => $username);

my $num_runs = scalar @id_run;
my $num_errors = 0;
foreach my $id_run (@id_run) {
  try {
    # Query the tracking database to get the run. This provides two items of
    # metadata; the run folder name to use as a surrogate for "run_name" and
    # the instrument model.
    my $run = $tracking_db->resultset('Run')->find({ id_run => $id_run });
    if (not defined $run) {
      croak "Failed to find run with id_run $id_run\n";
    }

    # Query ML warehouse for pool identifier to use as a surrogate for
    # "library_name".Tag zero reads are those not assigned when deplexing.
    my $rs = $warehouse_db->resultset("IseqProductMetric")->search
        ({ "me.id_run"    => $id_run,
           "me.tag_index" => { ">" => 0 } }, # Ignore tag zero
         { prefetch => "iseq_flowcell" });

    my @pool_ids = uniq map {$_->iseq_flowcell->id_pool_lims} $rs->all;
    if (not @pool_ids) {
      croak sprintf q[No id_pool_lims found in tracking for run_id %d], $id_run;
    }

    my $num_pool_ids = scalar @pool_ids;
    if ($num_pool_ids > 1) {
      croak sprintf q[Expected 1 id_pool_lims in tracking for run_id %d, ] .
                    q[but found %d], $id_run, $num_pool_ids;
    }

    $library_name     ||= $pool_ids[0];
    $instrument_make  ||= 'ILLUMINA';
    $instrument_model ||= $run->instrument->instrument_format->model;

    my $run_name = $run->folder_name;
    my $heron_run = npg_tracking::heron::upload::run->new
        (name             => $run_name,
         instrument_make  => $instrument_make,
         instrument_model => $instrument_model);

    if ($dry_run) {
      $log->info(sprintf q[DRY: id_run: %d, instrument_make: %s, instrument_model: %s, ] .
                         q[run_name: %s, library_name: %s],
                         $id_run, $instrument_make, $instrument_model,
                         $run_name, $library_name);
    }
    else {
      $client->send_metadata($library_name, $heron_run);
    }
  } catch {
    $log->error($_);
    $num_errors++;
  };
}

my $msg = sprintf q[Processed %d runs with %d errors], $num_runs, $num_errors;
if ($num_errors == 0) {
  $log->info($msg)
}
else {
  $log->logcroak($msg);
}

1;
