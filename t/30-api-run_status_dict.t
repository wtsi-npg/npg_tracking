#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-03-01 10:36:10 +0000 (Thu, 01 Mar 2012) $
# Id:            $Id: 30-api-run_status_dict.t 15277 2012-03-01 10:36:10Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/30-api-run_status_dict.t $
#
use strict;
use warnings;
use Test::Deep;
use Test::More tests => 31;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 15277 $ =~ /(\d+)/mx; $r; };

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/npg_api';

use_ok('npg::api::run_status_dict');

my $rsd = npg::api::run_status_dict->new();
isa_ok($rsd, 'npg::api::run_status_dict');

{
  my $rsd  = npg::api::run_status_dict->new({'id_run_status_dict' => 5,});
  my $rsds = $rsd->run_status_dicts();

  my $rsds_length = scalar @{$rsds};
  is($rsds_length, 24, 'Correct number of status lines returned');

  my $first_status = @{$rsds}[0]->{description};
  is($first_status, 'run pending', 'First status is run pending');

  my $temporal_current_ordered = [
    { id_run_status_dict => "1", description => "run pending"},
    { id_run_status_dict => "2", description =>  "run in progress"},
    { id_run_status_dict => "3", description =>  "run on hold"},
    { id_run_status_dict => "4", description =>  "run cancelled"}, 
    { id_run_status_dict => "5", description =>  "run stopped early"}, 
    { id_run_status_dict => "6", description =>  "run complete"}, 
    { id_run_status_dict => "7", description =>  "run mirrored"}, 
    { id_run_status_dict => "8", description =>  "analysis pending"}, 
    { id_run_status_dict => "9", description =>  "analysis cancelled"}, 
    { id_run_status_dict => "10", description =>  "data discarded"}, 
    { id_run_status_dict => "11", description =>  "analysis on hold"}, 
    { id_run_status_dict => "12", description =>  "analysis in progress"}, 
    { id_run_status_dict => "13", description =>  "secondary analysis in progress"}, 
    { id_run_status_dict => "14", description =>  "analysis complete"}, 
    { id_run_status_dict => "15", description =>  "qc review pending"}, 
    { id_run_status_dict => "16", description =>  "qc in progress"}, 
    { id_run_status_dict => "17", description =>  "qc on hold"}, 
    { id_run_status_dict => "18", description =>  "archival pending"}, 
    { id_run_status_dict => "19", description =>  "archival in progress"}, 
    { id_run_status_dict => "20", description =>  "run archived"},
    { id_run_status_dict => "21", description =>  "qc complete"},
  ];
 
  my $id_run_ordered = [
    { id_run_status_dict => "1", description => "run pending"},
    { id_run_status_dict => "2", description =>  "run in progress"},
    { id_run_status_dict => "3", description =>  "run on hold"},
    { id_run_status_dict => "4", description =>  "run complete"}, 
    { id_run_status_dict => "5", description =>  "run cancelled"}, 
    { id_run_status_dict => "6", description =>  "analysis pending"}, 
    { id_run_status_dict => "7", description =>  "analysis in progress"}, 
    { id_run_status_dict => "8", description =>  "analysis on hold"}, 
    { id_run_status_dict => "9", description =>  "analysis complete"}, 
    { id_run_status_dict => "10", description =>  "analysis cancelled"}, 
    { id_run_status_dict => "11", description =>  "run mirrored"}, 
    { id_run_status_dict => "12", description =>  "run archived"},
    { id_run_status_dict => "14", description =>  "analysis prelim"}, 
    { id_run_status_dict => "15", description =>  "analysis prelim complete"}, 
    { id_run_status_dict => "16", description =>  "run quarantined"}, 
    { id_run_status_dict => "17", description =>  "archival pending"}, 
    { id_run_status_dict => "18", description =>  "archival in progress"}, 
    { id_run_status_dict => "19", description =>  "qc review pending"}, 
    { id_run_status_dict => "20", description =>  "qc complete"},
    { id_run_status_dict => "21", description =>  "data discarded"}, 
    { id_run_status_dict => "22", description =>  "run stopped early"}, 
    { id_run_status_dict => "24", description =>  "secondary analysis in progress"}, 
    { id_run_status_dict => "25", description =>  "qc on hold"}, 
    { id_run_status_dict => "26", description =>  "qc in progress"}, 
  ];

  is(scalar @{$id_run_ordered}, 24, 'All run status values');
  is(scalar @{$temporal_current_ordered}, 21, 
    'Only want current run status values in temporal order');

  for (my $index = 0; $index < $rsds_length; $index++){
    my $status = @{$rsds}[$index]->{description};
    my $expected_status = @{$id_run_ordered}[$index]->{description};
    is($status, $expected_status, "Status $status is in correct order");
  }

  my $runs = $rsd->runs();
  is(scalar @{$runs}, 2);
}

1
;
