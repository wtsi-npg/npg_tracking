#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-04-28
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-administration.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-administration.t $
#

use strict;
use warnings;
use t::util;

use Test::More tests => 4;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 14928 $ =~ /(\d+)/mx; $r; };

use_ok('npg::model::administration');
my $util  = t::util->new({fixtures => 1});
{
  my $model = npg::model::administration->new({
             util     => $util,
            });
  is($model->instrument_mod_dict_descriptions()->[0]->[0], 'Mode Scrambler', 'instrument mod dict description');
  is($model->users()->[0]->username(), 'joe_admin', 'user joe_admin');
  is($model->usergroups()->[0]->groupname(), 'admin', 'usergroup admin');
}

1;
