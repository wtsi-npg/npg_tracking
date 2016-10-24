use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use t::util;

use_ok('npg::model::user');
use_ok('npg::view::user');

my $util = t::util->new({
                fixtures => 1,
                fixtures_path => q[t/data/fixtures],
      });

{
  my $model = npg::model::user->new({
             util     => $util,
             id_user  => 1,
             username => 'test',
            });
  $util->requestor($model);
  my $view  = npg::view::user->new({
            util   => $util,
            model  => $model,
            action => 'read',
            aspect => 'list',
           });

  isa_ok($view, 'npg::view::user');
  ok($util->test_rendered($view->render(), 't/data/rendered/user.html'), '20-view-user-list rendered ok');
}

{
  my $model = npg::model::user->new({
             util     => $util,
             id_user  => 1,
             username => 'test',
            });
  $util->requestor($model);

  my $view = npg::view::user->new({
           util   => $util,
           action => 'read',
           aspect => 'read',
           model  => $model,
          });

  my $str;
  lives_ok { $str = $view->render();} q{no croak rendering read};
  ok($util->test_rendered($str, 't/data/rendered/user/1000.html'), '20-view-user-read rendered ok');
}

1;
