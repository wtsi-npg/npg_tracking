#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 20-view-usergroup.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/20-view-usergroup.t $
#
use strict;
use warnings;
use Test::More tests => 6;
use t::util;
use npg::model::usergroup;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

use_ok('npg::view::usergroup');

my $util = t::util->new({fixtures=>1});

{
  my $model = npg::model::usergroup->new({
					  util         => $util,
					  id_usergroup => 1000,
					 });
  my $view  = npg::view::usergroup->new({
					 util   => $util,
					 model  => $model,
					 action => 'read',
					 aspect => 'list',
					});

  isa_ok($view, 'npg::view::usergroup');
  is($model->id_usergroup(), 1000);
}

{
  my $model = npg::model::usergroup->new({
					  util         => $util,
					  id_usergroup => 'testg',
					 });
  my $view  = npg::view::usergroup->new({
					 util   => $util,
					 model  => $model,
					 action => 'read',
					 aspect => 'list',
					});

  isa_ok($view, 'npg::view::usergroup');
  is($model->groupname(), 'testg');
}

{
  my $model = npg::model::usergroup->new({
					  util => $util,
					 });
  my $view  = npg::view::usergroup->new({
					 util   => $util,
					 model  => $model,
					 action => 'read',
					 aspect => 'list',
					});

  isa_ok($view, 'npg::view::usergroup');
}
