#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-01-11
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-run_status-active_runs.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-run_status-active_runs.t $
#
use strict;
use warnings;
use Test::More tests => 5;
use t::util;
use_ok('npg::model::run_status');

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 14928 $ =~ /(\d+)/mx; $r; };

my $mock = {
	           q(SELECT id_run, date
               FROM run_status
               WHERE date > DATE_SUB(NOW(), INTERVAL 30 DAY)
               AND id_run_status_dict in (SELECT id_run_status_dict
                                          FROM run_status_dict
                                          WHERE description in ('run in progress', 'run on hold', 'run complete'))
               ORDER BY date:) => [{ id_run => 1000, date => 'first day' }, { id_run => 1000, date => 'second day' }],
           };

my $util = t::util->new({'mock'=>$mock});

{
  my $model = npg::model::run_status->new({ util => $util });
  $model->{'active_runs_over_last_30_days'} = 1;
  my $active_runs_over_last_30_days = $model->active_runs_over_last_30_days();
  is($active_runs_over_last_30_days, 1, 'does not fetch active runs from database if present already');
  $model->{'active_runs_over_last_30_days'} = undef;
  $active_runs_over_last_30_days = $model->active_runs_over_last_30_days();
  isnt($active_runs_over_last_30_days, undef, 'fetches active runs from database if not already present');
  is($active_runs_over_last_30_days->[0]{date}, 'first day', 'Testing retrieval of information is as expected');
  is($active_runs_over_last_30_days->[1]{date}, 'second day', 'Testing retrieval of information is as expected');
}
1;
