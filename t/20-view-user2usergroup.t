use strict;
use warnings;
use Test::More tests => 12;
use t::util;
use npg::model::user;
use npg::model::user2usergroup;
use CGI;
use English qw(-no_match_vars);

my $util = t::util->new({fixtures => 1});

use_ok('npg::view::user2usergroup');

{
  my $view = npg::view::user2usergroup->new({util=> $util});
  isa_ok($view, 'npg::view::user2usergroup');
}


{
  my $model = npg::model::user2usergroup->new({
                 util => $util,
                 id_user_usergroup => 3
                });
  my $view = npg::view::user2usergroup->new({
               util   => $util,
               model  => $model,
               action => 'create',
              });
  is($view->authorised(), undef, 'public unauthorised for create');
}

{
  $util->requestor('joe_engineer');
  my $model = npg::model::user2usergroup->new({
                 util => $util,
                 id_user_usergroup => 3
                });
  my $view = npg::view::user2usergroup->new({
               util   => $util,
               model  => $model,
               action => 'create',
              });
  is($view->authorised(), 1, 'joe_engineer authorised for create');
}

{
  $util->requestor('joe_engineer');
  my $model = npg::model::user2usergroup->new({
                 util => $util,
                 id_user_usergroup => 3
                });
  my $view = npg::view::user2usergroup->new({
               util   => $util,
               model  => $model,
               action => 'delete',
              });
  is($model->id_user(), $util->requestor->id_user(), 'fixture user ids match');
  is($view->authorised(), 1, 'joe_engineer authorised for delete');
}

my $new_membership_id;

{
  my $model = npg::model::user2usergroup->new({
                 util => $util,
                });
  $util->requestor('joe_engineer');

  my $cgi = CGI->new();
  $cgi->param('id_usergroup', 3); # subscribe to 'Analysis Notifications'
  $util->{cgi} = $cgi;

  my $view = npg::view::user2usergroup->new({
               util   => $util,
               model  => $model,
               action => 'create',
              });

  is($util->requestor->is_member_of('results'), undef, 'not a member of group');

  $view->create();

  my $user2 = npg::model::user->new({
             util     => $util,
             username => 'joe_engineer',
            });
  is($user2->is_member_of('results'), 1, 'is a member of group');

  $new_membership_id = $model->id_user_usergroup();
}

{
  my $model = npg::model::user2usergroup->new({
                 id_user_usergroup => $new_membership_id,
                 util => $util,
                });
  $util->requestor('joe_engineer');

  my $view = npg::view::user2usergroup->new({
               util   => $util,
               model  => $model,
               action => 'delete',
              });

  is($util->requestor->is_member_of('results'), 1, 'is a member of group');

  $view->delete();

  my $user2 = npg::model::user->new({
             util     => $util,
             username => 'joe_engineer',
            });
  is($user2->is_member_of('results'), undef, 'not a member of group');
}

{
  my $model = npg::model::user2usergroup->new({
                 util => $util,
                });
  $util->requestor('joe_engineer');
  $util->{cgi} = CGI->new();

  my $view = npg::view::user2usergroup->new({
               util   => $util,
               model  => $model,
               action => 'create',
              });
  eval {
    $view->create();
  };
  like($EVAL_ERROR, qr/no\ group/mix, 'fail to subscribe to undef group');
}

{
  my $model = npg::model::user2usergroup->new({
                 util => $util,
                });
  $util->requestor('joe_engineer');
  my $cgi = CGI->new();
  $cgi->param('id_usergroup', 1);
  $util->{cgi} = $cgi;

  my $view = npg::view::user2usergroup->new({
               util   => $util,
               model  => $model,
               action => 'create',
              });
  eval {
    $view->create();
  };
  like($EVAL_ERROR, qr/not\ open\ for\ subscription/mix, 'fail to subscribe to non-public group');
}
