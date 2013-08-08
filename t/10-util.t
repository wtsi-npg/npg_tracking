#########
# Author:        rmp
# Created:       2007-10
# copied from svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-util.t r16269
#
use strict;
use warnings;
use Test::More tests => 9;

local $ENV{dev}='test';

use_ok('npg::util');
my $util = npg::util->new();
isa_ok($util, q(npg::util));
my $cfg = $util->config();
isa_ok($cfg, q(Config::IniFiles));

is($util->decription_key, 'abcd', 'test decription key');
is($util->data_path, 'data', 'default data path');
{
  is(npg::util->dbsection, 'test', 'test db section');
  local $ENV{'dev'} = q[];
  is(npg::util->dbsection, 'live', 'live db section');
  local $ENV{'dev'} = q[dev];
  is(npg::util->dbsection, 'dev', 'dev db section');
  local $ENV{'NPG_DATA_ROOT'} = '/some/path';
  is($util->data_path, '/some/path', 'data path from NPG_DATA_ROOT');
}
1;
