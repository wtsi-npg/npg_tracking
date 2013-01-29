#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-03-08 11:21:27 +0000 (Thu, 08 Mar 2012) $
# Id:            $Id: 10-model-search-advanced.t 15308 2012-03-08 11:21:27Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-search-advanced.t $
#
use strict;
use warnings;
use Test::More tests => 44;
use CGI;
use t::util;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 15308 $ =~ /(\d+)/mx; $r; };
use_ok('npg::model::search');

  my $mock = {
    q(SELECT DISTINCT run.id_run
      FROM run, run_status_dict, run_status
      WHERE run_status_dict.description = 'run pending'
      AND DATE(run_status.date) >= DATE('2008-01-01')
      AND run_status_dict.id_run_status_dict = run_status.id_run_status_dict
      AND run.id_run = run_status.id_run:) => [{id_run => 1000}],
    q(SELECT DISTINCT run.id_run FROM run:) => [{id_run => 1000}],
    q(SELECT DISTINCT run.id_run FROM run WHERE run.id_run = 10:) => [{ id_run => 10 }],
    q(SELECT DISTINCT run.id_run, instrument.id_instrument, instrument.name
      FROM run, instrument
      WHERE instrument.name = 'IL1000'
      AND instrument.id_instrument = run.id_instrument:) => [{
                                                              id_instrument => 1000,
                                                              name          => 'IL1000',
                                                              id_run        => 134
                                                             },{
                                                              id_instrument => 1000,
                                                              name          => 'IL1000',
                                                              id_run        => 135
                                                             }],
    q(SELECT DISTINCT run.id_run, instrument.id_instrument, instrument.name
      FROM run, run_status_dict, run_status, user, instrument
      WHERE run_status_dict.description = 'run pending'
      AND user.username = 'djt'
      AND run.id_run = run_status.id_run
      AND run_status_dict.id_run_status_dict = run_status.id_run_status_dict
      AND user.id_user = run_status.id_user
      AND instrument.id_instrument = run.id_instrument:) => [{
                                                                id_instrument => 1000,
                                                                name          => 'IL1000',
                                                                id_run        => 134
                                                               }],
    q(SELECT DISTINCT run.id_run, annotation.id_annotation, annotation.comment
      FROM run, annotation, run_annotation
      WHERE annotation.comment like '%good%'
      AND run.id_run = run_annotation.id_run
      AND annotation.id_annotation = run_annotation.id_annotation:) => [{
                                                                id_annotation => 1000,
                                                                comment       => 'This is a good run',
                                                                id_run        => 134
                                                               }],
    q(SELECT DISTINCT run.id_run, annotation.id_annotation, annotation.comment
      FROM run, annotation, run_annotation
      WHERE annotation.comment like '%bad%'
      AND run.id_run = run_annotation.id_run
      AND annotation.id_annotation = run_annotation.id_annotation:) => [],
    q(SELECT DISTINCT run.id_run, annotation.id_annotation, annotation.comment
      FROM run, annotation, run_annotation
      WHERE annotation.comment like '%good%'
      AND run.id_run = run_annotation.id_run
      AND annotation.id_annotation = run_annotation.id_annotation:) => [{
                                                                id_annotation => 1000,
                                                                comment       => 'This is a good run',
                                                                id_run        => 134
                                                               }],
    q(SELECT DISTINCT run.id_run
      FROM run, run_status_dict, run_status
      WHERE run_status_dict.description = 'run pending'
      AND DATE(run_status.date) >= DATE('2008-01-01')
      AND DATE(run_status.date) <= DATE('2008-02-28')
      AND run.id_run = run_status.id_run
      AND run_status_dict.id_run_status_dict = run_status.id_run_status_dict:) => [{id_run => 1000}],
    q(SELECT DISTINCT run.id_run
      FROM run, run_status_dict, run_status
      WHERE run_status_dict.description = 'run pending'
      AND DATE(run_status.date) >= DATE('2008-01-01')
      AND DATE(run_status.date) <= DATE('2008-12-31')
      AND run.id_run = run_status.id_run
      AND run_status_dict.id_run_status_dict = run_status.id_run_status_dict:) => [{id_run => 1000}],
    q(SELECT DISTINCT run.id_run
      FROM run, run_status_dict, run_status
      WHERE run_status_dict.description = 'run pending'
      AND DATE(run_status.date) <= DATE('2008-12-31')
      AND run.id_run = run_status.id_run
      AND run_status_dict.id_run_status_dict = run_status.id_run_status_dict:) => [{id_run => 1000}],
    q(SELECT DISTINCT run.id_run
      FROM run, run_status_dict, run_status
      WHERE run_status_dict.description = 'run pending'
      AND DATE(run_status.date) >= DATE('2008-01-01')
      AND run.id_run = run_status.id_run
      AND run_status_dict.id_run_status_dict = run_status.id_run_status_dict:) => [{id_run => 1000}],
    q(SELECT DISTINCT run.id_run, run.batch_id FROM run WHERE run.team = 'RAD' AND run.is_paired = 1:) => [{
                                                                                         batch_id => 244,
                                                                                         id_run   => 134
                                                                                        },{
                                                                                         batch_id => 244,
                                                                                         id_run   => 156
                                                                                        }],
  };
{
  my $cgi = CGI->new();
  $cgi->param('annotation', 'good');
  $cgi->param('annotations', 1);
  
  my $util = t::util->new({ mock => $mock, cgi => $cgi });
  my $model = npg::model::search->new({ util => $util });
warn $util.q{:}.$model . q{:}. $mock;
  my $results = $model->advanced_search();
  is(scalar @{$results}, 1, '1 result - creates a query via a joining table');
  my @keys =  @{$model->{'result_keys'}};
  is(scalar@keys, 3, '3 keys');
  is($results->[0]->[0], 134, 'id_run ok');
  is($model->{'result_keys'}->[1], 'comment', 'first result key correct');

}
{

  my $cgi = CGI->new();
  $cgi->param('id_run', 10);

  my $util = t::util->new({ mock => $mock, cgi => $cgi });
  my $model = npg::model::search->new({ util => $util });

  isa_ok($model, 'npg::model::search');
  isa_ok($model->search_conditions(), 'HASH', 'search conditions');
  isa_ok($model->search_for(), 'HASH', 'search for');
  isa_ok($model->foreign_keys(), 'HASH', 'foreign keys');
  
  my $results = $model->advanced_search();
  is(scalar @{$results}, 1, 'only 1 result');
  is(@{$model->{'result_keys'}}, 1, 'one key');
  is($model->{'result_keys'}->[0], 'id_run', 'id_run is expected key');
}
{
  my $cgi = CGI->new();
  $cgi->param('annotation', 'good');
  $cgi->param('annotations', 1);
  
  my $util = t::util->new({ mock => $mock, cgi => $cgi });
  my $model = npg::model::search->new({ util => $util });
  $model->{results} = 'test';
  my $results = $model->advanced_search();
  is($results, 'test', 'no query made if $model->{results} already present');

}

{
  my $cgi = CGI->new();
  $cgi->param('instruments', 1);
  $cgi->param('instrument', 'IL1000');
  
  my $util = t::util->new({ mock => $mock, cgi => $cgi });
  my $model = npg::model::search->new({ util => $util });

  my $results = $model->advanced_search();
  is(scalar @{$results}, 2, '2 results - creates a query where only 2 tables were needed');
  my @keys = @{$model->{'result_keys'}};
  is(scalar@keys, 3, '3 keys');
  is($keys[0], 'id_run', 'id_run in correct position in array');
  is($results->[1]->[0], 135, 'id_run ok and in correct position in array');

}

{
  my $cgi = CGI->new();
  $cgi->param('instruments', 1);
  $cgi->param('loader', 'djt');
  
  my $util = t::util->new({ mock => $mock, cgi => $cgi });
  my $model = npg::model::search->new({ util => $util });

  my $results = $model->advanced_search();
  is(scalar @{$results}, 1, '1 result - creates a query where multiple froms are used');
  my @keys = @{$model->{'result_keys'}};
  is(scalar@keys, 3, '3 keys');
  is($keys[0], 'id_run', 'id_run in correct position in array');
  is($results->[0]->[0], 134, 'id_run ok and in correct position in array');

}

{
  my $cgi = CGI->new();
  $cgi->param('annotation', 'bad');
  $cgi->param('annotations', 1);
  
  my $util = t::util->new({ mock => $mock, cgi => $cgi });
  my $model = npg::model::search->new({ util => $util });

  my $results = $model->advanced_search();
  is(scalar @{$results}, 1, '1 result expected, as id_run enforced to be first');
  is(@{$model->{'result_keys'}}, 1, 'id_run key');

}
{
  my $cgi = CGI->new();
  $cgi->param('runs', 1);
  
  my $util = t::util->new({ mock => $mock, cgi => $cgi });
  my $model = npg::model::search->new({ util => $util });

  my $results = $model->advanced_search();
  is(scalar @{$results}, 1, '1 result - just a select runs');
  is(@{$model->{'result_keys'}}, 1, '1 key - just a select runs');

}
{
  my $cgi = CGI->new();
  $cgi->param('from', '2008-01-01');
  $cgi->param('to', '2008-02-28');
  $cgi->param('status', 'run pending');
  
  my $util = t::util->new({ mock => $mock, cgi => $cgi });
  my $model = npg::model::search->new({ util => $util });

  my $results = $model->advanced_search();
  is(scalar @{$results}, 1, '1 result - date from and to');
  is(@{$model->{'result_keys'}}, 1, '1 key - date from and to');

}
{
  my $cgi = CGI->new();
  $cgi->param('from', '2008-01-01');
  $cgi->param('to', '2008-12-31');
  $cgi->param('status', 'run pending');
  
  my $util = t::util->new({ mock => $mock, cgi => $cgi });
  my $model = npg::model::search->new({ util => $util });

  my $results = $model->advanced_search();
  is(scalar @{$results}, 1, '1 result - date from and to');
  is(@{$model->{'result_keys'}}, 1, '1 key - date from and to');

}
{
  my $cgi = CGI->new();
  $cgi->param('to', '2008-12-31');
  $cgi->param('status', 'run pending');
  
  my $util = t::util->new({ mock => $mock, cgi => $cgi });
  my $model = npg::model::search->new({ util => $util });

  my $results = $model->advanced_search();
  is(scalar @{$results}, 1, '1 result - date to');
  is(@{$model->{'result_keys'}}, 1, '1 key - date to');

}
{

  my $cgi = CGI->new();
  $cgi->param('from', '2008-01-01');
  $cgi->param('status', 'run pending');
  
  my $util = t::util->new({ mock => $mock, cgi => $cgi });
  my $model = npg::model::search->new({ util => $util });

  my $results = $model->advanced_search();
  is(scalar @{$results}, 1, '1 result - date from');
  is(@{$model->{'result_keys'}}, 1, '1 key - date from');

}
{
  my $cgi = CGI->new();
  
  my $util = t::util->new({ mock => $mock, cgi => $cgi });
  my $model = npg::model::search->new({ util => $util });

  my $results = $model->advanced_search();
  is(scalar@{$results}, 1, 'default query run with no cgi params');

}
{
  my $mock = {
  };

  my $cgi = CGI->new();
  $cgi->param('from', '2008-01-01');
  $cgi->param('status', 'run pending');
  
  my $util = t::util->new({ mock => $mock, cgi => $cgi });
  my $model = npg::model::search->new({ util => $util });

  my (@where, @from, %from_seen);

  $model->date_conditions(\@where, \@from, \%from_seen);
  ok($from_seen{run_status}, '$from_seen{run_status}');
  ok($from_seen{run_status_dict}, '$from_seen{run_status_dict}');

}
{
  my $cgi = CGI->new();
  $cgi->param('batches', 1);
  $cgi->param('dev', 1);
  $cgi->param('paired', 1);
  
  my $util = t::util->new({ mock => $mock, cgi => $cgi });
  my $model = npg::model::search->new({ util => $util });

  my $results = $model->advanced_search();
  is(scalar @{$results}, 2, '2 results - creates a query from only a single table');
  my @keys = @{$model->{'result_keys'}};
  is(scalar@keys, 2, '2 keys');
  is($keys[1], 'batch_id', 'batch_id in correct position in array');
  is($results->[1]->[1], 244, 'batch_id ok and in correct position in array');

}
# changed as util now singleton within scope of whole test file - change to fixtures asap
$mock->{q(SELECT DISTINCT run.id_run FROM run:)} = [{id_run => 1}, {id_run => 2}];
$mock->{q(SELECT tr.id_run, t.tag FROM tag t, tag_run tr WHERE t.id_tag = tr.id_tag AND tr.id_run in (1,2) ORDER BY tr.id_run:)} = [{id_run => 1, tag => 'good'}, {id_run => 1, tag => 'superb'}];
{
  my $cgi   = CGI->new();
  $cgi->param('run_tags', 1);
  my $util  = t::util->new({ mock => $mock, cgi => $cgi });
  my $model = npg::model::search->new({ util => $util });
  $model->advanced_search();
  isa_ok($model->{result_keys}, 'ARRAY', 'result_keys');
  is($model->{result_keys}->[-1], 'tags', 'tags column header present');
  is($model->{results}->[0]->[-1], 'good superb', 'tags shown');
  is($model->{results}->[1]->[-1], undef, 'no tags shown');
}
