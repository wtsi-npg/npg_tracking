use strict;
use warnings;
use Test::More tests => 5;
use Test::Trap;
use CGI;

use t::util;

$ENV{SCRIPT_NAME} = '/cgi-test/npg';

use_ok('npg::controller');

{
  my $util = t::util->new({fixtures => 1});
  trap {
    ok(npg::controller->handler($util));
  };
  is($util->username(), q[], q[user is not defined]);

  my $cgi = CGI->new();
  $cgi->param('pipeline', 1);
  $util->cgi($cgi);
  trap {
    ok(npg::controller->handler($util));
  };
  is($util->username(), q[], q[pipeline user is not special in any way]);
}

1;
