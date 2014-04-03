use strict;
use warnings;
use Test::More tests => 13;
use English qw(-no_match_vars);
use t::util;

use_ok('npg::view::error');

my $util = t::util->new({fixtures => 1});

{
  my $view = npg::view::error->new({
              util => $util,
             });
  isa_ok($view, 'npg::view::error', 'constructs ok');
}
{
  my $view = npg::view::error->new({
              util => $util,
              aspect => q{add},
              action => q{list},
             });
  my $model = {};
  $util->catch_email($model);
  my $render;
  eval{$render = $view->render()};
  is($EVAL_ERROR, q{}, 'no croak on render with aspect add');
  is(scalar@{$model->{emails}}, 0, 'no email sent, as authentication error');
  ok($util->test_rendered($render, q{t/data/rendered/error/add.html}), 'html output for error on add ok');
}
{
  my $view = npg::view::error->new({
              util => $util,
              aspect => q{},
              action => q{list},
             });
  my $model = {};

  $util->catch_email($model);
  my $render;
  eval{$render = $view->render()};
  is($EVAL_ERROR, q{}, 'no croak on render with action list');
  ok($util->test_rendered($render, q{t/data/rendered/error/list.html}), 'html output for error on list ok');
  is(scalar@{$model->{emails}}, 1, 'email sent, as not authentication error');

  my $parsed_email = $util->parse_email($model->{emails}->[0]);
  like($parsed_email->{annotation}, qr/\[\d{4}[-]\d{2}[-]\d{2}T\d{2}:\d{2}:\d{2}\]Error: -\n\nCheck the error logs to find out the problem[.]\n\nThe following user was logged in: public/ms, 'body is an error');
  like($parsed_email->{subject}, qr/test[ ]NPG[ ]Error/, 'subject is correct');
  like($parsed_email->{to}, qr/rt_error[@]sanger[.]ac[.]uk/, 'to is correct');
  like($parsed_email->{from}, qr/srpipe[@]sanger[.]ac[.]uk/, 'from is correct');
}

# check that no emails are sent if there are no members of the errors group
{
  my $user = npg::model::user->new({
            util => $util,
            username => q{rt_error},
           });
  my $usergroup = $user->usergroups()->[0];
  my $uug = npg::model::user2usergroup->new( {
    util => $util,
    id_user => $user->id_user(),
    id_usergroup => $usergroup->id_usergroup(),
   } );
  $uug->delete();

  my $view = npg::view::error->new({
            util => $util,
            aspect => q{},
            action => q{list},
           });
  my $model = {};
  $util->catch_email($model);
  my $render;
  eval{$render = $view->render()};
  is( scalar @{ $model->{emails} }, 0, q{no emails sent as no members of errors usergroup} );
}
1;
