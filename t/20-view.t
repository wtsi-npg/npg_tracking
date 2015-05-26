use Test::More tests => 3;

local $ENV{'HOME'}=q(t/data);

use_ok('npg::view');

{
  is_deeply(npg::view->staging_urls(), {},
    'no args, no conf file - empty hash returned');
  is_deeply(npg::view->staging_urls('gs01'), {},
    'args given, no conf file - empty hash returned');
}

1;
