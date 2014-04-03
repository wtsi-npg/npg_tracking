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
