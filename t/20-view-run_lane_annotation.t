use strict;
use warnings;
use Test::More tests => 31;
use English qw(-no_match_vars);
use t::util;
use npg::model::run_lane_annotation;
use npg::model::annotation;
use IO::Scalar;

our $TEST_ANNOTATION_COMMENT = 'A test annotation for a run lane';
use_ok('npg::view::run_lane_annotation');

my $util = t::util->new({
       fixtures  => 1,
      });
{
  my $cgi = CGI->new();
  $util->cgi($cgi);
  my $model = npg::model::run_lane_annotation->new({
                util => $util,
               });
  my $view  = npg::view::run_lane_annotation->new({
               util   => $util,
               model  => $model,
               action => 'create',
               aspect => 'create_xml',
              });
  $util->catch_email($model);

  isa_ok($view, 'npg::view::run_lane_annotation', '$view');

##########
# testing authorisation method
#

  is($view->authorised(), undef, 'create xml aspect/create action - public not authorised');
  $view->action('update');
  is($view->authorised(), undef, 'update action - public not authorised');
  $view->action('read');
  is($view->authorised(), undef, 'read action - public not authorised');

  $view->action('create');
  $util->requestor('pipeline');
  is($view->authorised(), 1, 'create xml aspect - pipeline authorised');
  $view->action('read');
  $view->aspect('read_attachment');
  is($view->authorised(), 1, 'read xml aspect - pipeline authorised');

  $view->aspect(q{});
  $util->requestor('joe_loader');
  is($view->authorised(), 1, 'create action - loader authorised');
    $view->action('read');
  is($view->authorised(), 1, 'read action - loader authorised');

  $util->requestor('joe_engineer');
  is($view->authorised(), 1, 'read action - engineer authorised');
  $view->action('create');
  is($view->authorised(), 1, 'create action - engineer authorised');

  $util->requestor('joe_annotator');
  is($view->authorised(), 1, 'create action - annotator authorised');
  $view->action('read');
  is($view->authorised(), 1, 'read action - annotator authorised');

###########
# testing decor
#

  $view->aspect('read_attachment');
  is($view->decor(), 0, 'no decor for read_attachment aspect');

  $view->action('create');
  $view->aspect(q{});
  is($view->decor(), 1, 'decor ok for create action');

###########
# testing create
#

  $cgi->param('comment',        $TEST_ANNOTATION_COMMENT);
  $cgi->param('last_lane',      q[]);
  $cgi->param('id_run_lane',    1);
  $model->{id_entity_type} = 10;

  eval { $view->create(); };
  is($EVAL_ERROR, q{}, 'no croak on create without attachment');
}

{
  my $cgi = CGI->new();
  $util->cgi($cgi);

  my $model = npg::model::run_lane_annotation->new({
                util => $util,
               });
  my $view  = npg::view::run_lane_annotation->new({
               util   => $util,
               model  => $model,
               action => 'create',
              });
  $cgi->param('comment',     q[no comment]);
  $cgi->param('id_run_lane', 1);
  $cgi->param('attachment',  IO::Scalar->new(\'some content'));

  $util->catch_email($model);
  eval { $view->create(); };
  is($EVAL_ERROR, q{}, 'no croak on create with attachment');
}

{
  my $cgi = CGI->new();
  $util->cgi($cgi);

  my $model = npg::model::run_lane_annotation->new({
                util => $util,
               });
  my $view  = npg::view::run_lane_annotation->new({
               util   => $util,
               model  => $model,
               action => 'create',
              });
  $cgi->param('comment',     q[no comment]);
  $cgi->param('id_run_lane', 1);
  $cgi->param('attachment',  IO::Scalar->new(\'some content'));
  $cgi->param('attachment_name','bar');

  $util->catch_email($model);
  eval { $view->create(); };
  is($EVAL_ERROR, q{}, 'no croak on create with attachment_name passed through');
}

{
  my $cgi = CGI->new();
  $util->cgi($cgi);

  my $model = npg::model::run_lane_annotation->new({
                util => $util,
               });
  my $view  = npg::view::run_lane_annotation->new({
               util   => $util,
               model  => $model,
               action => 'create',
              });
  $cgi->param('comment',     q[no comment]);
  $cgi->param('id_run_lane', 1);
  $cgi->param('attachment',  IO::Scalar->new(\'some content'));
  $cgi->param('username',    'pipeline');
  $util->catch_email($model);
  $util->requestor('pipeline');
  eval { $view->create(); };
  is($EVAL_ERROR, q{}, 'no croak on create as pipeline');

#########
# testing read_attachment if's in new
#

  $view  = npg::view::run_lane_annotation->new({
            util                   => $util,
            model                  => $model,
            id_run_lane_annotation => 3,
            action                 => 'read',
            aspect                 => 'read_attachment_xml',
                 });
  isa_ok($view, 'npg::view::run_lane_annotation', '$view - no attachment');

  my $annotation = npg::model::annotation->new({
            util       => $util,
            attachment => "foo\n",
                 });

  $model = npg::model::run_lane_annotation->new({
             util       => $util,
             annotation => $annotation,
            });
  $view  = npg::view::run_lane_annotation->new({
            util                   => $util,
            model                  => $model,
            id_run_lane_annotation => 11,
            action                 => 'read',
            aspect                 => 'read_attachment_xml',
                 });
  isa_ok($view, 'npg::view::run_lane_annotation', '$view - has attachment');

##########
# testing render
#

  is($view->render(), "foo\n", 'attachment renders ok');

}

{
  my $render;
  my $cgi = CGI->new();
  $util->cgi($cgi);

  my $model = npg::model::run_lane_annotation->new({
                util => $util,
               });
  my $view  = npg::view::run_lane_annotation->new({
               util  => $util,
               model => $model,
               action => 'create',
              });
  $util->requestor('joe_annotator');
  $util->catch_email($model);
  $cgi->param('comment', $TEST_ANNOTATION_COMMENT);
  $cgi->param('id_run_lane', 1);
  eval{ $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on render of create');
  ok($util->test_rendered($render, 't/data/rendered/20-view-run_lane_annotation_not_bad_lane.html'), 'create render');
}

{
  my $render;
  my $cgi = CGI->new();
  $util->cgi($cgi);

  my $model = npg::model::run_lane_annotation->new({
                util => $util,
               });
  my $view  = npg::view::run_lane_annotation->new({
               util  => $util,
               model => $model,
               action => 'create',
              });
  $util->requestor('joe_annotator');
  $util->catch_email($model);
  $cgi->param('comment', $TEST_ANNOTATION_COMMENT);
  $cgi->param('id_run_lane', 1);
  $cgi->param('last_lane', q{});
  $cgi->param('bad_lane', 1);
  eval{ $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on render of create');
  ok($util->test_rendered($render, 't/data/rendered/20-view-run_lane_annotation_bad_lane_not_last.html'), 'create render with bad lane but not last lane');
}

{
  my $render;
  my $cgi = CGI->new();
  $util->cgi($cgi);

  my $model = npg::model::run_lane_annotation->new({
                util => $util,
               });
  my $view  = npg::view::run_lane_annotation->new({
               util   => $util,
               model  => $model,
               action => 'create',
              });
  $util->requestor('joe_annotator');
  $util->catch_email($model);
  $cgi->param('comment', $TEST_ANNOTATION_COMMENT);
  $cgi->param('id_run_lane', 1);
  $cgi->param('last_lane', 1);
  $cgi->param('bad_lane', 1);
  eval{ $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak on render of create');
  ok($util->test_rendered($render, 't/data/rendered/20-view-run_lane_annotation_bad_lane_and_last.html'), 'create render with bad lane and is the last lane');
}

{
  my $render;
  my $cgi = CGI->new();
  $util->cgi($cgi);
  $cgi->param('id_run_lane',1);
  $util->requestor('public');

  my $model = npg::model::run_lane_annotation->new({
                util       => $util,
                id_run_lane => 1,
               });
  my $view  = npg::view::run_lane_annotation->new({
               util   => $util,
               model  => $model,
               action => 'read',
               aspect => 'add_ajax',
              });
  eval{ $render = $view->render(); };
  isnt($EVAL_ERROR, q[], 'public add_ajax should croak');

  $util->requestor('joe_annotator');
  eval{ $render = $view->render(); };
  is($EVAL_ERROR, q{}, 'no croak as annotator');
  ok($util->test_rendered($render, 't/data/rendered/20-view-run_lane_annotation_add_ajax.html'), 'create render with bad lane and is the last lane');
}


1;
