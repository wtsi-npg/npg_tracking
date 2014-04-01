use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;

use_ok('npg_tracking::util::messages');

{
  my $list = npg_tracking::util::messages->new();
  isa_ok($list, 'npg_tracking::util::messages', 'is test');
}

{
  my $l = npg_tracking::util::messages->new();
  my $message1 = q[first_message];
  lives_ok { $l->push($message1) } 'push to an empty list';
  my $message2 = q[second_message];
  lives_ok { $l->push($message2) } 'push to a non-empty list';
  is($l->count, 2, 'message count is 2');
  is(join(q[;], $l->messages()), (join q[;], $message1, $message2), 'all mesages retrieved');
}
