#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-03-27 13:38:46 +0100 (Tue, 27 Mar 2012) $
# Id:            $Id: 20-view-user.t 15395 2012-03-27 12:38:46Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/20-view-user.t $
#
use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use t::util;
use npg::model::user;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 15395 $ =~ /(\d+)/mx; $r; };

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